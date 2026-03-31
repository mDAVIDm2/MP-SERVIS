import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/settings/filter_by_car_setting.dart';
import '../../../../core/settings/favorite_sto_ids_provider.dart';
import '../../../../core/settings/preferred_directions_map_provider.dart';
import '../../../../core/settings/sto_reviews_provider.dart';
import '../../../../shared/models/car_model.dart';
import '../../../../shared/models/external_poi.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/navigation/shell_navigation_provider.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/sto_model.dart';
import '../../../../shared/organization_ui_copy.dart';
import '../../data/external_poi_cache.dart';
import '../../data/overpass_poi_service.dart';
import '../widgets/sto_osm_map.dart';
import 'sto_detail_screen.dart';

/// Расстояние между двумя точками в км (формула гаверсинусов).
double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371.0; // радиус Земли в км
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return R * c;
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with TickerProviderStateMixin {
  bool _isMapView = true;
  int _selectedFilter = 0;
  final _searchController = TextEditingController();
  Position? _userPosition;
  bool _locationRequested = false;
  /// При включённой «Сортировать по машине» — false = только точки по выбранной машине, true = показать все.
  bool _showAllOrganizations = false;
  /// Показывать ли на карте недобавленные организации (красные метки).
  bool _showExternalPOIsOnMap = false;
  /// Фильтр по расстоянию (км), null — не ограничивать. Применяется из модалки «Фильтры».
  double? _maxDistanceKm;
  /// Минимальный рейтинг (например 3.0, 4.0, 4.5), null — любой. Применяется из модалки «Фильтры».
  double? _minRating;
  /// Выбранные ID услуг для фильтра (AND: точка должна оказывать все выбранные услуги).
  List<String> _selectedServiceIds = [];

  bool _mapReady = false;
  MapController? _osmMapController;

  /// Таймер ожидания геолокации (3 сек): по истечении показываем кнопку «Моё местоположение».
  Timer? _locationWaitTimer;
  bool _showMyLocationButton = false;
  bool _locationWaitTimerStarted = false;

  /// Внешние POI (красные метки). Загружаются по видимой области из кэша или Overpass. При 429/ошибке список не очищается.
  List<ExternalPOI> _externalPOIs = [];
  bool _externalPOIsLoading = false;
  Timer? _debounceTimer;
  final _overpassPoi = OverpassPoiService();
  final _externalPoiCache = ExternalPOICache();

  /// Текущий зум карты для масштабирования размера маркеров (меньше при отдалении).
  double _currentZoom = 14.0;
  /// Текущий центр карты (для плавной анимации к выбранной точке).
  LatLng? _lastMapCenter;

  /// Чипы типа организации — совпадают с `business_kind` на бэкенде (фильтр уходит в API).
  static const List<({String? kind, String label})> _orgKindChips = [
    (kind: null, label: 'Все'),
    (kind: 'sto', label: 'Автосервис'),
    (kind: 'car_wash', label: 'Мойка'),
    (kind: 'detailing', label: 'Детейлинг'),
    (kind: 'tire_service', label: 'Шиномонтаж'),
    (kind: 'body_shop', label: 'Кузовной'),
    (kind: 'car_audio', label: 'Автозвук'),
    (kind: 'glass', label: 'Стёкла'),
    (kind: 'ev_service', label: 'EV'),
    (kind: 'tuning', label: 'Тюнинг'),
    (kind: 'other', label: 'Другое'),
  ];

  /// Базовый список точек из API/поиска; затем применяются локальные фильтры (машина, рейтинг, расстояние, услуги).
  /// [skipCarFilter] — чтобы понять, скрыла ли пустой список именно привязка к марке авто.
  List<STO> _getFilteredSTOs(WidgetRef ref, List<STO> baseList, {bool skipCarFilter = false}) {
    var list = List<STO>.from(baseList);
    if (_selectedServiceIds.isNotEmpty) {
      list = list.where((s) => _selectedServiceIds.every((id) => s.serviceIds.contains(id))).toList();
      list = list.map((s) {
        int price = 0;
        int duration = 0;
        for (final svc in s.services) {
          if (_selectedServiceIds.contains(svc.id)) {
            price += svc.priceKopecks;
            duration += svc.durationMinutes;
          }
        }
        return s.copyWith(totalSelectedPriceKopecks: price, totalSelectedDurationMinutes: duration);
      }).toList();
    }
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((s) =>
        s.name.toLowerCase().contains(query) ||
        s.address.toLowerCase().contains(query) ||
        s.specializations.any((sp) => sp.toLowerCase().contains(query))
      ).toList();
    }
    final filterByCar = ref.watch(filterByCarSettingProvider);
    final selectedId = ref.watch(selectedCarIdProvider);
    if (!skipCarFilter && filterByCar && selectedId != null && !_showAllOrganizations) {
      final cars = ref.watch(carsProvider).valueOrNull ?? [];
      Car? car;
      try {
        car = cars.firstWhere((c) => c.id == selectedId);
      } catch (_) {}
      if (car != null) {
        list = list.where((s) => stoMatchesCarBrand(s.specializations, car!.brand)).toList();
      }
    }
    if (_minRating != null) {
      list = list.where((s) => s.rating >= _minRating!).toList();
    }
    if (_maxDistanceKm != null && _userPosition != null) {
      list = list.where((s) {
        if (s.latitude == null || s.longitude == null) return true;
        final d = _distanceKm(_userPosition!.latitude, _userPosition!.longitude, s.latitude!, s.longitude!);
        return d <= _maxDistanceKm!;
      }).toList();
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  String? get _selectedOrgKindForCatalog {
    final i = _selectedFilter.clamp(0, _orgKindChips.length - 1);
    return _orgKindChips[i].kind;
  }

  Future<void> _showServiceFilterSheet(BuildContext context, WidgetRef ref) async {
    final catalog = await ref.read(catalogServicesProvider(_selectedOrgKindForCatalog).future);
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => _ServiceFilterSheetContent(
          categories: catalog.categories,
          items: catalog.items,
          initialSelectedIds: List.from(_selectedServiceIds),
          onApply: (ids) {
            setState(() => _selectedServiceIds = ids);
            Navigator.pop(ctx);
          },
          onReset: () {
            setState(() => _selectedServiceIds = []);
            Navigator.pop(ctx);
          },
          scrollController: scrollController,
        ),
      ),
    );
  }

  /// Запрашивает геолокацию. [onReceived] вызывается при успешном получении (можно переместить карту).
  Future<void> _requestUserLocation([void Function(Position)? onReceived]) async {
    if (_locationRequested) return;
    _locationRequested = true;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
        );
        if (mounted) {
          setState(() => _userPosition = pos);
          onReceived?.call(pos);
        }
      }
    } catch (_) {}
  }

  /// Запускает ожидание геолокации при открытии карты: через 3 сек без результата показываем кнопку «Моё местоположение».
  void _startLocationWaitForMap() {
    if (_locationWaitTimerStarted) return;
    _locationWaitTimerStarted = true;
    _locationWaitTimer?.cancel();
    _locationWaitTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _userPosition == null) setState(() => _showMyLocationButton = true);
    });
  }

  /// Переместить карту к пользователю с плавной анимацией (как при тапе по точке); при отсутствии геолокации — запросить.
  Future<void> _moveMapToUserLocation() async {
    if (_userPosition != null) {
      _animateMapToCenterAndZoom(
        LatLng(_userPosition!.latitude, _userPosition!.longitude),
        15.0,
      );
      return;
    }
    _showMyLocationButton = false;
    _locationRequested = false;
    _locationWaitTimerStarted = false;
    _locationWaitTimer?.cancel();
    _startLocationWaitForMap();
    _requestUserLocation((pos) {
      _locationWaitTimer?.cancel();
      if (mounted) {
        _animateMapToCenterAndZoom(LatLng(pos.latitude, pos.longitude), 15.0);
      }
    });
  }

  @override
  void dispose() {
    _locationWaitTimer?.cancel();
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Максимум POI в сессии, чтобы не раздувать память при долгом перемещении по карте.
  static const int _maxSessionPOIs = 800;

  /// Объединяет уже загруженные POI с новыми по id (без дубликатов). Ограничение по количеству.
  static List<ExternalPOI> _mergeSessionPOIs(List<ExternalPOI> existing, List<ExternalPOI> incoming) {
    final ids = existing.map((p) => p.id).toSet();
    final merged = List<ExternalPOI>.from(existing);
    for (final p in incoming) {
      if (ids.add(p.id)) merged.add(p);
      if (merged.length >= _maxSessionPOIs) break;
    }
    if (merged.length > _maxSessionPOIs) return merged.sublist(0, _maxSessionPOIs);
    return merged;
  }

  /// Загрузить внешние организации по заданным границам карты.
  /// Кэш + Overpass. Результаты мержатся в сессионный список.
  Future<void> _fetchExternalPOIsForBounds(double minLat, double minLng, double maxLat, double maxLng) async {
    if (!mounted) return;
    try {
      List<ExternalPOI> list = await _externalPoiCache.get(minLat, minLng, maxLat, maxLng) ?? [];

      if (list.isNotEmpty) {
        if (mounted) setState(() {
          _externalPOIs = _mergeSessionPOIs(_externalPOIs, list);
          _externalPOIsLoading = false;
        });
        return;
      }

      if (mounted) setState(() => _externalPOIsLoading = true);

      list = await _overpassPoi.searchInBounds(
        minLat: minLat,
        minLng: minLng,
        maxLat: maxLat,
        maxLng: maxLng,
      );

      if (list.isNotEmpty) {
        await _externalPoiCache.put(minLat, minLng, maxLat, maxLng, list);
      }

      if (mounted) {
        setState(() {
          if (list.isNotEmpty) _externalPOIs = _mergeSessionPOIs(_externalPOIs, list);
          _externalPOIsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _externalPOIsLoading = false);
    }
  }

  /// Внешние POI для карты с учётом выбранного фильтра категории.
  List<ExternalPOI> _getFilteredExternalPOIs() {
    if (_selectedFilter == 0) return _externalPOIs;
    final idx = _selectedFilter.clamp(0, _orgKindChips.length - 1);
    final label = _orgKindChips[idx].label;
    return _externalPOIs.where((p) => p.types.contains(label)).toList();
  }

  /// Внешние POI для отображения на карте: без дубликатов партнёров (в радиусе 50 м).
  List<ExternalPOI> _getExternalPOIsForMap(List<STO> withCoords) {
    return _getFilteredExternalPOIs()
        .where((p) => !withCoords.any((s) =>
            _distanceKm(p.lat, p.lng, s.latitude!, s.longitude!) < 0.05))
        .toList();
  }

  /// Плавная двухфазная анимация: смещение к точке, затем зум (~2–2.5 с). [onComplete] вызывается в конце.
  void _animateMapToCenterAndZoom(LatLng target, double targetZoom, {VoidCallback? onComplete}) {
    final controller = _osmMapController;
    if (!_mapReady || controller == null) {
      onComplete?.call();
      return;
    }
    final startCenter = _lastMapCenter ?? target;
    final startZoom = _currentZoom;

    if (startCenter.latitude == target.latitude && startCenter.longitude == target.longitude && (startZoom - targetZoom).abs() < 0.2) {
      onComplete?.call();
      return;
    }

    const phase1Duration = Duration(milliseconds: 1000);
    const phase2Duration = Duration(milliseconds: 1200);

    final phase1 = AnimationController(duration: phase1Duration, vsync: this);
    final curve1 = CurvedAnimation(parent: phase1, curve: Curves.easeInOut);
    final latTween = Tween<double>(begin: startCenter.latitude, end: target.latitude);
    final lngTween = Tween<double>(begin: startCenter.longitude, end: target.longitude);

    void onPhase1Tick() {
      if (!mounted || _osmMapController == null) return;
      _osmMapController!.move(
        LatLng(latTween.evaluate(curve1), lngTween.evaluate(curve1)),
        startZoom,
      );
    }

    phase1.addListener(onPhase1Tick);
    phase1.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      phase1.removeListener(onPhase1Tick);
      phase1.dispose();
      if (!mounted) return;

      final phase2 = AnimationController(duration: phase2Duration, vsync: this);
      final curve2 = CurvedAnimation(parent: phase2, curve: Curves.easeInOut);
      final zoomTween = Tween<double>(begin: startZoom, end: targetZoom);

      void onPhase2Tick() {
        if (!mounted || _osmMapController == null) return;
        _osmMapController!.move(target, zoomTween.evaluate(curve2));
      }

      phase2.addListener(onPhase2Tick);
      phase2.addStatusListener((s) {
        if (s != AnimationStatus.completed) return;
        phase2.removeListener(onPhase2Tick);
        phase2.dispose();
        if (mounted) onComplete?.call();
      });
      phase2.forward();
    });
    phase1.forward();
  }

  /// Плавно смещаем карту к точке, затем приближаем и открываем экран детали (общая длительность ~2–2.5 с).
  void _animateToStoAndOpen(STO sto) {
    final initialIds = _selectedServiceIds.isNotEmpty ? _selectedServiceIds : null;
    if (sto.latitude == null || sto.longitude == null) {
      pushCupertino(context, STODetailScreen(sto: sto, initialServiceIds: initialIds));
      return;
    }
    if (!_mapReady || _osmMapController == null) {
      pushCupertino(context, STODetailScreen(sto: sto, initialServiceIds: initialIds));
      return;
    }
    final target = LatLng(sto.latitude!, sto.longitude!);
    const targetZoom = 16.0;
    final startCenter = _lastMapCenter ?? target;
    final startZoom = _currentZoom;

    if (startCenter.latitude == target.latitude && startCenter.longitude == target.longitude && (startZoom - targetZoom).abs() < 0.2) {
      pushCupertino(context, STODetailScreen(sto: sto, initialServiceIds: initialIds));
      return;
    }

    _animateMapToCenterAndZoom(target, targetZoom, onComplete: () {
      if (mounted) pushCupertino(context, STODetailScreen(sto: sto, initialServiceIds: initialIds));
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<String>?>(searchServiceFilterBootstrapProvider, (prev, next) {
      if (next == null || next.isEmpty) return;
      final copy = List<String>.from(next);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(searchServiceFilterBootstrapProvider.notifier).state = null;
        setState(() => _selectedServiceIds = copy);
      });
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: SizedBox(
                height: 56,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Поиск сервиса', style: AppTextStyles.screenTitle),
                ),
              ),
            ),
            // Строка поиска
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    const Icon(Icons.search_rounded, size: 22, color: AppColors.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Название, адрес или услуга',
                          hintStyle: TextStyle(color: AppColors.textPlaceholder, fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showServiceFilterSheet(context, ref),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.filter_list_rounded, size: 22, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Чипы выбранных услуг (при активном фильтре)
            if (_selectedServiceIds.isNotEmpty)
              Consumer(
                builder: (context, ref, _) {
                  final catalogAsync = ref.watch(catalogServicesProvider(null));
                  final names = catalogAsync.valueOrNull?.items.fold<Map<String, String>>({}, (m, i) => (m..[i.id] = i.name)) ?? {};
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ..._selectedServiceIds.map((id) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Chip(
                              label: Text(names[id] ?? id, style: const TextStyle(fontSize: 12)),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () => setState(() => _selectedServiceIds = _selectedServiceIds.where((x) => x != id).toList()),
                            ),
                          )),
                          TextButton(
                            onPressed: () => setState(() => _selectedServiceIds = []),
                            child: const Text('Сбросить всё'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            // Переключатель: Карта / Список (по умолчанию открыта карта)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    _SegmentBtn(label: 'Карта', active: _isMapView,
                      onTap: () => setState(() => _isMapView = true)),
                    _SegmentBtn(label: 'Список', active: !_isMapView,
                      onTap: () => setState(() => _isMapView = false)),
                  ],
                ),
              ),
            ),
            // Фильтры
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _orgKindChips.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  if (i == _orgKindChips.length) {
                    return GestureDetector(
                      onTap: () => _showFilters(context),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.tune_rounded, size: 18, color: AppColors.textSecondary),
                      ),
                    );
                  }
                  final isActive = i == _selectedFilter;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFilter = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isActive ? AppColors.primary : AppColors.border),
                      ),
                      alignment: Alignment.center,
                      child: Text(_orgKindChips[i].label, style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500,
                        color: isActive ? const Color(0xFF0D0D0D) : AppColors.textSecondary,
                      )),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            // Контент: список точек с сервера (поиск) + локальные фильтры
            Expanded(
              child: Builder(
                builder: (context) {
                  final searchQuery = _searchController.text.trim();
                  final chipIdx = _selectedFilter.clamp(0, _orgKindChips.length - 1);
                  final businessKind = _orgKindChips[chipIdx].kind;
                  final searchAsync = ref.watch(stoSearchProvider((
                    query: searchQuery.isEmpty ? null : searchQuery,
                    businessKind: businessKind,
                  )));
                  final baseList = searchAsync.valueOrNull ?? [];
                  final list = _getFilteredSTOs(ref, baseList);
                  return _isMapView
                      ? _buildMapView(list, ref)
                      : _buildList(list, ref, baseList: baseList, searchAsync: searchAsync);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<STO> stos, WidgetRef ref, {required List<STO> baseList, required AsyncValue<List<STO>> searchAsync}) {
    if (searchAsync.isLoading && baseList.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (searchAsync.hasError && baseList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            OrganizationUiCopy.listLoadError(),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final showShowAllFooter = ref.watch(filterByCarSettingProvider) &&
        ref.watch(selectedCarIdProvider) != null;
    final itemCount = stos.length + (showShowAllFooter ? 1 : 0);

    if (itemCount == 0) {
      final isServiceFilter = _selectedServiceIds.isNotEmpty;
      final filterByCar = ref.watch(filterByCarSettingProvider);
      final selectedCarId = ref.watch(selectedCarIdProvider);
      final listIgnoringCar = _getFilteredSTOs(ref, baseList, skipCarFilter: true);
      final hiddenByCarFilter = baseList.isNotEmpty &&
          !isServiceFilter &&
          filterByCar &&
          selectedCarId != null &&
          !_showAllOrganizations &&
          listIgnoringCar.isNotEmpty;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 64, color: AppColors.textTertiary),
              const SizedBox(height: 16),
              Text(
                isServiceFilter
                    ? OrganizationUiCopy.emptyAllServicesSelected()
                    : (hiddenByCarFilter
                        ? OrganizationUiCopy.emptyCarBrandHidden()
                        : 'Ничего не найдено'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isServiceFilter
                    ? 'Попробуйте изменить набор услуг или сбросить фильтр'
                    : (hiddenByCarFilter
                        ? 'Нажмите «Показать все» ниже или отключите «Сортировать по машине» в профиле'
                        : 'Измените фильтр или поисковый запрос'),
                style: const TextStyle(fontSize: 14, color: AppColors.textTertiary),
                textAlign: TextAlign.center,
              ),
              if (hiddenByCarFilter) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => setState(() => _showAllOrganizations = true),
                  child: Text(OrganizationUiCopy.showAllOrganizations()),
                ),
              ],
              if (isServiceFilter) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => setState(() => _selectedServiceIds = []),
                      child: const Text('Сбросить фильтр'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () => _showServiceFilterSheet(context, ref),
                      child: const Text('Изменить набор услуг'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        if (_selectedServiceIds.isNotEmpty && stos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              OrganizationUiCopy.foundOrganizations(stos.length),
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            if (i == stos.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: GestureDetector(
                    onTap: () => setState(() => _showAllOrganizations = !_showAllOrganizations),
                    child: Text(
                      _showAllOrganizations ? 'Скрыть все' : 'Показать все',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              );
            }
            final sto = stos[i];
            final allReviews = ref.watch(stoReviewsProvider);
            final userReviews = allReviews.where((r) => r.stoId == sto.id).toList();
            final displayRating = StoReviewsNotifier.computedRating(sto.rating, sto.reviewCount, userReviews);
            final displayReviewCount = StoReviewsNotifier.computedReviewCount(sto.reviewCount, userReviews);
            return _SearchSTOCard(
          sto: sto,
          displayRating: displayRating,
          displayReviewCount: displayReviewCount,
          compact: false,
          isFavorite: ref.watch(effectiveFavoriteStoIdsProvider).contains(sto.id),
          onFavoriteTap: () {
            ref.read(favoriteStoStateProvider.notifier).toggle(
                  sto.id,
                  filterByCar: ref.read(filterByCarSettingProvider),
                  selectedCarId: ref.read(selectedCarIdProvider),
                );
            HapticFeedback.lightImpact();
          },
          onTap: () => pushCupertino(context, STODetailScreen(
            sto: sto,
            initialServiceIds: _selectedServiceIds.isNotEmpty ? _selectedServiceIds : null,
          )),
          onCall: (s) => _openCallForSto(context, s),
          onRoute: (s) => _openRouteToSto(context, s),
          onShare: (_) => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Поделиться — в следующей версии')),
          ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMapView(List<STO> stos, WidgetRef ref) {
    final withCoords = stos.where((s) => s.latitude != null && s.longitude != null).toList();
    const krasnodar = LatLng(45.0355, 38.9753);
    final userLat = _userPosition?.latitude;
    final userLon = _userPosition?.longitude;
    final userLocation = (userLat != null && userLon != null) ? LatLng(userLat, userLon) : null;
    // В центре карты — пользователь (если есть геолокация), иначе Краснодар.
    final initialCenter = userLocation ?? krasnodar;
    final initialZoom = userLocation != null ? 14.0 : (withCoords.length > 1 ? 11.0 : 13.0);
    if (_isMapView) {
      _requestUserLocation((pos) {
        _locationWaitTimer?.cancel();
        if (mounted) {
          setState(() {});
          _animateMapToCenterAndZoom(LatLng(pos.latitude, pos.longitude), 15.0);
        }
      });
      _startLocationWaitForMap();
    }

    // В рекомендациях сверху — топ-6 по рейтингу
    final recommended = withCoords.isEmpty
        ? <STO>[]
        : (List<STO>.from(withCoords)..sort((a, b) => b.rating.compareTo(a.rating))).take(6).toList();

    final showShowAllOnMap = ref.watch(filterByCarSettingProvider) &&
        ref.watch(selectedCarIdProvider) != null;

    return Stack(
      children: [
        STOOSMMap(
          initialCenter: initialCenter,
          initialZoom: initialZoom,
          partners: withCoords,
          externals: _showExternalPOIsOnMap ? _getExternalPOIsForMap(withCoords) : [],
          userLocation: userLocation,
          onPartnerTap: _animateToStoAndOpen,
          onExternalTap: (poi) => _showExternalPOICard(context, poi),
          onMapReady: () => setState(() {
            _mapReady = true;
            if (_lastMapCenter == null) _lastMapCenter = initialCenter;
          }),
          onCameraMove: (zoom) => setState(() => _currentZoom = zoom),
          onCameraChanged: (center, zoom) => setState(() {
            _lastMapCenter = center;
            _currentZoom = zoom;
          }),
          onControllerReady: (c) => setState(() => _osmMapController = c),
          onVisibleBoundsChanged: _fetchExternalPOIsForBounds,
        ),
        // Рекомендованные точки — горизонтальная полоса сверху (как было изначально)
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (recommended.isNotEmpty)
                    SizedBox(
                      height: 54,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: recommended.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final sto = recommended[i];
                          final distKm = (userLat != null && userLon != null && sto.latitude != null && sto.longitude != null)
                              ? _distanceKm(userLat, userLon, sto.latitude!, sto.longitude!)
                              : sto.distanceKm;
                          return Material(
                            color: AppColors.cardBg.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () => _animateToStoAndOpen(sto),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.location_on_rounded, size: 20, color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          sto.name,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(Icons.star_rounded, size: 12, color: AppColors.primary),
                                            const SizedBox(width: 2),
                                            Text(
                                              Formatters.rating(sto.rating),
                                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                            ),
                                            if (distKm != null) ...[
                                              const SizedBox(width: 6),
                                              Text(
                                                Formatters.distance(distKm),
                                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 6),
                                    Material(
                                      color: AppColors.nestedBg,
                                      borderRadius: BorderRadius.circular(8),
                                      child: InkWell(
                                        onTap: () => _openRouteToSto(context, sto),
                                        borderRadius: BorderRadius.circular(8),
                                        child: const Padding(
                                          padding: EdgeInsets.all(6),
                                          child: Icon(Icons.directions_rounded, size: 18, color: AppColors.primary),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  if (stos.isNotEmpty && withCoords.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Material(
                        color: AppColors.cardBg.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(12),
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline_rounded, size: 22, color: AppColors.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'На карте не видно точек без координат. Во вкладке «Список» они отображаются.',
                                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.35),
                                ),
                              ),
                              TextButton(
                                onPressed: () => setState(() => _isMapView = false),
                                child: const Text('Список'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        // Кнопка «Моё местоположение» — правый нижний угол (если геолокация не успела за 3 сек или для перехода к себе)
        if (_showMyLocationButton || _userPosition != null)
          Positioned(
            right: 12,
            bottom: MediaQuery.of(context).padding.bottom + 16 + 52,
            child: SafeArea(
              top: false,
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(28),
                color: AppColors.cardBg.withValues(alpha: 0.95),
                child: IconButton(
                  onPressed: _moveMapToUserLocation,
                  icon: const Icon(Icons.my_location_rounded, color: AppColors.primary, size: 26),
                  tooltip: 'Моё местоположение',
                ),
              ),
            ),
          ),
        // Меню отображения карты — правый нижний угол
        Positioned(
          right: 12,
          bottom: MediaQuery.of(context).padding.bottom + 16,
          child: SafeArea(
            top: false,
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(28),
              color: AppColors.cardBg.withValues(alpha: 0.95),
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                offset: const Offset(0, -140),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                icon: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(Icons.layers_rounded, color: AppColors.primary, size: 26),
                ),
                onSelected: (value) {
                  if (value == 'external') setState(() => _showExternalPOIsOnMap = !_showExternalPOIsOnMap);
                  if (value == 'all_orgs') setState(() => _showAllOrganizations = !_showAllOrganizations);
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'external',
                    child: Row(
                      children: [
                        Icon(_showExternalPOIsOnMap ? Icons.visibility_off_rounded : Icons.place_rounded, size: 20, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            _showExternalPOIsOnMap ? 'Скрыть непартнёрские' : 'Отобразить непартнёрские',
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showShowAllOnMap)
                    PopupMenuItem<String>(
                      value: 'all_orgs',
                      child: Row(
                        children: [
                          Icon(Icons.directions_car_rounded, size: 20, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              _showAllOrganizations ? 'С фильтром по марке' : 'Без фильтра по марке',
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Карточка внешней организации: название, типы, адрес, сообщение «не сотрудничает», Позвонить, Маршрут.
  void _showExternalPOICard(BuildContext context, ExternalPOI poi) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, -4))],
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    poi.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (poi.types.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: poi.types
                          .map((t) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(t, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ))
                          .toList(),
                    ),
                  ],
                  if (poi.address != null && poi.address!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on_outlined, size: 16, color: AppColors.textTertiary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            poi.address!,
                            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text(
                      'Данная организация не сотрудничает с AutoHub',
                      style: TextStyle(fontSize: 13, color: AppColors.textTertiary, height: 1.3),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (poi.phone != null && poi.phone!.isNotEmpty)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              _openCallForExternalPOI(context, poi);
                            },
                            icon: const Icon(Icons.phone_rounded, size: 18),
                            label: const Text('Позвонить'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                            ),
                          ),
                        ),
                      if (poi.phone != null && poi.phone!.isNotEmpty) const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _openRouteToExternalPOI(context, poi);
                          },
                          icon: const Icon(Icons.directions_rounded, size: 18),
                          label: const Text('Маршрут'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Закрыть'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCallForExternalPOI(BuildContext context, ExternalPOI poi) async {
    if (poi.phone == null || poi.phone!.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет номера для звонка'), behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }
    final digits = poi.phone!.replaceAll(RegExp(r'[^\d+]'), '');
    try {
      await launchUrl(Uri.parse('tel:$digits'), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть набор номера'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  /// Открыть маршрут: если закреплён навигатор в настройках — открыть его, иначе выбор один раз с сохранением.
  Future<void> _openRouteWithMapLauncher({
    required double destLat,
    required double destLng,
    required String destinationTitle,
  }) async {
    final available = await MapLauncher.installedMaps;
    if (available.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет установленных карт для маршрута'), behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }
    Coords? origin;
    if (_userPosition != null) {
      origin = Coords(_userPosition!.latitude, _userPosition!.longitude);
    }
    final destination = Coords(destLat, destLng);

    final preferredType = ref.read(preferredDirectionsMapProvider);
    if (preferredType != null && preferredType.isNotEmpty) {
      final preferred = available.where((m) => m.mapType.name == preferredType).firstOrNull;
      if (preferred != null) {
        try {
          await preferred.showDirections(
            destination: destination,
            destinationTitle: destinationTitle,
            origin: origin,
            originTitle: 'Моё местоположение',
          );
          return;
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Не удалось открыть карты'), behavior: SnackBarBehavior.floating),
            );
          }
          return;
        }
      }
    }

    if (available.length == 1) {
      ref.read(preferredDirectionsMapProvider.notifier).set(available.first.mapType.name);
      try {
        await available.first.showDirections(
          destination: destination,
          destinationTitle: destinationTitle,
          origin: origin,
          originTitle: 'Моё местоположение',
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось открыть карты'), behavior: SnackBarBehavior.floating),
          );
        }
      }
      return;
    }
    if (!mounted) return;
    final chosen = await showModalBottomSheet<AvailableMap>(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Выберите навигатор', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ),
            ...available.map((map) => ListTile(
              leading: const Icon(Icons.map_rounded, color: AppColors.primary, size: 28),
              title: Text(directionsMapDisplayName(map), style: const TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(ctx, map),
            )),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    ref.read(preferredDirectionsMapProvider.notifier).set(chosen.mapType.name);
    try {
      await chosen.showDirections(
        destination: destination,
        destinationTitle: destinationTitle,
        origin: origin,
        originTitle: 'Моё местоположение',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть карты'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _openRouteToExternalPOI(BuildContext context, ExternalPOI poi) async {
    await _openRouteWithMapLauncher(
      destLat: poi.lat,
      destLng: poi.lng,
      destinationTitle: poi.name,
    );
  }

  Future<void> _openCallForSto(BuildContext context, STO sto) async {
    final phones = sto.displayPhones;
    if (phones.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет номера для звонка'), backgroundColor: AppColors.error),
        );
      }
      return;
    }
    String? selected;
    if (phones.length == 1) {
      selected = phones.first;
    } else {
      selected = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          title: const Text('Выберите номер', style: TextStyle(color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: phones
                .map((n) => ListTile(
                      title: Text(Formatters.phone(n), style: const TextStyle(color: AppColors.textPrimary)),
                      onTap: () => Navigator.pop(ctx, n),
                    ))
                .toList(),
          ),
        ),
      );
    }
    if (selected != null) {
      final digits = selected.replaceAll(RegExp(r'[^\d+]'), '');
      try {
        await launchUrl(Uri.parse('tel:$digits'), mode: LaunchMode.externalApplication);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось открыть набор номера'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Future<void> _openRouteToSto(BuildContext context, STO sto) async {
    if (sto.latitude == null || sto.longitude == null) return;
    await _openRouteWithMapLauncher(
      destLat: sto.latitude!,
      destLng: sto.longitude!,
      destinationTitle: sto.name,
    );
  }

  void _showFilters(BuildContext context) {
    double tempMaxKm = _maxDistanceKm ?? 50;
    double? tempMinRating = _minRating;
    final ratingOptions = <String, double?>{'Любой': null, '3.0+': 3.0, '4.0+': 4.0, '4.5+': 4.5};

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Фильтры', style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
                    )),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Расстояние (км)', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: tempMaxKm.clamp(1.0, 50.0),
                        min: 1,
                        max: 50,
                        divisions: 49,
                        activeColor: AppColors.primary,
                        inactiveColor: AppColors.border,
                        onChanged: (v) {
                          tempMaxKm = v;
                          setModalState(() {});
                        },
                      ),
                    ),
                    SizedBox(width: 40, child: Text('${tempMaxKm.round()}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Минимальный рейтинг', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: ratingOptions.entries.map((e) {
                    final isSelected = tempMinRating == e.value;
                    return ChoiceChip(
                      label: Text(e.key),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.nestedBg,
                      labelStyle: TextStyle(
                        color: isSelected ? const Color(0xFF0D0D0D) : AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      onSelected: (_) {
                        tempMinRating = e.value;
                        setModalState(() {});
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          tempMaxKm = 50;
                          tempMinRating = null;
                          setModalState(() {});
                        },
                        child: const Text('Сбросить'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _maxDistanceKm = tempMaxKm >= 49.5 ? null : tempMaxKm;
                                _minRating = tempMinRating;
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Применить', style: TextStyle(
                              fontWeight: FontWeight.w600, color: Color(0xFF0D0D0D),
                            )),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SegmentBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SegmentBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(label, style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: active ? const Color(0xFF0D0D0D) : AppColors.textSecondary,
          )),
        ),
      ),
    );
  }
}

/// Оранжевый бейдж с суммой и временем по выбранным услугам.
class _PriceTimeBadge extends StatelessWidget {
  final int priceKopecks;
  final int durationMinutes;

  const _PriceTimeBadge({required this.priceKopecks, required this.durationMinutes});

  @override
  Widget build(BuildContext context) {
    final priceStr = Formatters.money(priceKopecks);
    final timeStr = Formatters.durationMinutes(durationMinutes);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE65100),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Text(
        '$priceStr · $timeStr',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
      ),
    );
  }
}

class _SearchSTOCard extends StatelessWidget {
  final STO sto;
  /// Рейтинг с учётом отзывов пользователей (если задан — показываем его вместо sto.rating).
  final double? displayRating;
  final int? displayReviewCount;
  final VoidCallback? onTap;
  final bool compact;
  final bool isFavorite;
  final VoidCallback? onFavoriteTap;
  final void Function(STO)? onCall;
  final void Function(STO)? onRoute;
  final void Function(STO)? onShare;
  const _SearchSTOCard({
    required this.sto,
    this.displayRating,
    this.displayReviewCount,
    this.onTap,
    this.compact = false,
    this.isFavorite = false,
    this.onFavoriteTap,
    this.onCall,
    this.onRoute,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.nestedBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(sto.name[0], style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary,
                  )),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            sto.name,
                            style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            onFavoriteTap?.call();
                          },
                          child: Icon(
                            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 22,
                            color: isFavorite ? AppColors.error : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: AppColors.primary),
                        const SizedBox(width: 2),
                        Text(
                          '${Formatters.rating(displayRating ?? sto.rating)} (${displayReviewCount ?? sto.reviewCount})',
                          style: const TextStyle(
                            fontSize: 14, color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(sto.address, style: const TextStyle(
                            fontSize: 14, color: AppColors.textSecondary,
                          ), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        if (sto.distanceKm != null)
                          Text(Formatters.distance(sto.distanceKm!), style: const TextStyle(
                            fontSize: 14, color: AppColors.textSecondary,
                          )),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: sto.isOpen ? AppColors.success : AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          sto.isOpen ? 'Открыто' : 'Закрыто',
                          style: TextStyle(
                            fontSize: 12,
                            color: sto.isOpen ? AppColors.success : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: sto.specializations.take(4).map((s) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.nestedBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(s, style: const TextStyle(fontSize: 11, color: AppColors.textPrimary)),
                      )).toList(),
                    ),
                    if (sto.minPrice != null) ...[
                      const SizedBox(height: 4),
                      Text(sto.minPrice!, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (onCall != null || onRoute != null || onShare != null) ...[
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onCall != null)
                    _ActionChip(icon: Icons.phone_rounded, label: 'Позвонить', onTap: () => onCall!(sto)),
                  if (onCall != null && (onRoute != null || onShare != null)) const SizedBox(width: 6),
                  if (onRoute != null)
                    _ActionChip(icon: Icons.directions_rounded, label: 'Маршрут', onTap: () => onRoute!(sto)),
                  if (onRoute != null && onShare != null) const SizedBox(width: 6),
                  if (onShare != null)
                    _ActionChip(icon: Icons.share_rounded, label: 'Поделиться', onTap: () => onShare!(sto)),
                ],
              ),
            ),
          ],
          if (sto.totalSelectedPriceKopecks != null && sto.totalSelectedPriceKopecks! > 0) ...[
            const SizedBox(height: 10),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.nestedBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    _PriceTimeBadge(
                      priceKopecks: sto.totalSelectedPriceKopecks!,
                      durationMinutes: sto.totalSelectedDurationMinutes ?? 0,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.nestedBg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceFilterSheetContent extends StatefulWidget {
  final List<CatalogCategory> categories;
  final List<CatalogServiceItem> items;
  final List<String> initialSelectedIds;
  final void Function(List<String> ids) onApply;
  final VoidCallback onReset;
  final ScrollController scrollController;

  const _ServiceFilterSheetContent({
    required this.categories,
    required this.items,
    required this.initialSelectedIds,
    required this.onApply,
    required this.onReset,
    required this.scrollController,
  });

  @override
  State<_ServiceFilterSheetContent> createState() => _ServiceFilterSheetContentState();
}

class _ServiceFilterSheetContentState extends State<_ServiceFilterSheetContent> {
  late Set<String> _selectedIds;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.initialSelectedIds);
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filteredItems = query.isEmpty
        ? widget.items
        : widget.items.where((i) => i.name.toLowerCase().contains(query)).toList();
    final byCategory = <String, List<CatalogServiceItem>>{};
    for (final cat in widget.categories) {
      final list = filteredItems.where((i) => i.categoryId == cat.id).toList();
      if (list.isNotEmpty) byCategory[cat.id] = list;
    }
    final uncategorized = filteredItems.where((i) => i.categoryId.isEmpty || !widget.categories.any((c) => c.id == i.categoryId)).toList();
    if (uncategorized.isNotEmpty) byCategory[''] = uncategorized;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Text('Фильтр по услугам', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const Spacer(),
                TextButton(
                  onPressed: widget.onReset,
                  child: const Text('Сбросить всё'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск по услугам',
                prefixIcon: const Icon(Icons.search_rounded, size: 22, color: AppColors.textSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                isDense: true,
              ),
            ),
          ),
          if (_selectedIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ...widget.items.where((i) => _selectedIds.contains(i.id)).map((i) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text(i.name, style: const TextStyle(fontSize: 12)),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => setState(() => _selectedIds.remove(i.id)),
                    ),
                  )),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              children: [
                for (final entry in byCategory.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Text(
                      entry.key.isEmpty ? 'Прочее' : (widget.categories.where((c) => c.id == entry.key).map((c) => c.name).firstOrNull ?? 'Услуги'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ),
                  ...entry.value.map((item) => CheckboxListTile(
                    value: _selectedIds.contains(item.id),
                    onChanged: (v) => setState(() {
                      if (v == true) _selectedIds.add(item.id);
                      else _selectedIds.remove(item.id);
                    }),
                    title: Text(item.name, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  )),
                ],
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
            color: AppColors.cardBg,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onReset,
                    child: const Text('Сбросить'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => widget.onApply(_selectedIds.toList()..sort()),
                    child: const Text('Применить'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
