import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/auth/auth_provider.dart' show authProvider, sharedPreferencesProvider;
import '../../../../core/catalog/client_catalog_service_ids.dart';
import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/l10n/l10n_scope.dart';
import '../../../../core/map/in_app_map_tiles.dart';
import '../../../../core/settings/map_provider_setting.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/settings/filter_by_car_setting.dart';
import '../../../../core/settings/favorite_sto_ids_provider.dart';
import '../../../../core/settings/sto_reviews_provider.dart';
import '../../../../shared/models/car_model.dart';
import '../../../../shared/models/external_poi.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/navigation/driving_route_launcher.dart';
import '../../../../core/navigation/shell_navigation_provider.dart';
import '../../../../core/onboarding/garage_first_car_tutorial_provider.dart';
import '../../../../core/onboarding/garage_tutorial_target.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/sto_model.dart';
import '../../data/external_poi_cache.dart';
import '../../data/overpass_poi_service.dart';
import '../widgets/location_preview_card.dart';
import '../widgets/sto_list_leading_image.dart';
import '../widgets/sto_osm_map.dart';
import '../widgets/sto_search_list_brands_line.dart';
import '../widgets/sto_working_hours_block.dart' show stoSearchCardTodayHoursLine;
import '../../../chats/presentation/screens/chat_detail_screen.dart';
import 'sto_detail_screen.dart';

/// Главный ряд фильтров: один пункт «Мойка»; подтипы мойки — [WashSubtype] и [_washExternalMatchUnion].
List<({String? kind, String label})> _mainOrgKindChips(AppL10n l10n) => [
      (kind: null, label: l10n.searchFilterAll),
      (kind: 'sto', label: l10n.searchKindSto),
      (kind: 'car_wash', label: l10n.searchKindCarWashGroup),
      (kind: 'detailing', label: l10n.searchKindDetailing),
      (kind: 'tire_service', label: l10n.searchKindTire),
      (kind: 'body_shop', label: l10n.searchKindBody),
      (kind: 'car_audio', label: l10n.searchKindCarAudio),
      (kind: 'other', label: l10n.searchKindOther),
    ];

/// Подтипы мойки (доп. чипы при выбранной «Мойка»).
enum WashSubtype {
  classic,
  selfService,
  robot,
}

const Set<String> _washMatchClassic = {'Мойка (классическая)', 'Мойка'};
const Set<String> _washMatchSelf = {'Мойка (самообслуживание)'};
const Set<String> _washMatchRobot = {'Мойка (робот)'};

Set<String> _washExternalMatchUnion(Set<WashSubtype> selected) {
  final out = <String>{};
  if (selected.contains(WashSubtype.classic)) out.addAll(_washMatchClassic);
  if (selected.contains(WashSubtype.selfService)) out.addAll(_washMatchSelf);
  if (selected.contains(WashSubtype.robot)) out.addAll(_washMatchRobot);
  return out;
}

Set<String>? _externalMatchForMainKind(String? kind) {
  switch (kind) {
    case 'sto':
      return {'Автосервис'};
    case 'detailing':
      return {'Детейлинг'};
    case 'tire_service':
      return {'Шиномонтаж'};
    case 'body_shop':
      return {'Кузовной'};
    case 'car_audio':
      return {'Автозвук'};
    case 'other':
      return <String>{};
    default:
      return null;
  }
}

/// Расширяет видимый bbox для Overpass: чуть больше радиус, по долготе (в стороны) в 2 раза шире, чем по широте (север–юг).
({double minLat, double minLng, double maxLat, double maxLng}) _expandBoundsForExternalFetch(
  double minLat,
  double minLng,
  double maxLat,
  double maxLng,
) {
  final cLat = (minLat + maxLat) / 2;
  final cLng = (minLng + maxLng) / 2;
  final halfLatVis = (maxLat - minLat) / 2;
  final halfLngVis = (maxLng - minLng) / 2;
  const minHalfLat = 0.055;
  const maxHalfLat = 0.125;
  // Запас по долготе к запасу по широте (в стороны шире), соотношение 2:1.
  const lngPerLat = 2.0;
  const maxHalfLng = 0.26;
  // Запас к видимой области: больше — POI подгружаются до сдвига в эту зону.
  var halfLat = (halfLatVis * 3.35).clamp(minHalfLat, maxHalfLat);
  var halfLng = (lngPerLat * halfLat).clamp(math.max(halfLngVis * 3.1, lngPerLat * minHalfLat * 0.9), maxHalfLng);
  return (
    minLat: (cLat - halfLat).clamp(-85.0, 85.0),
    minLng: (cLng - halfLng).clamp(-180.0, 180.0),
    maxLat: (cLat + halfLat).clamp(-85.0, 85.0),
    maxLng: (cLng + halfLng).clamp(-180.0, 180.0),
  );
}

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

/// Не обрезаем непартнёров по «оценочному» прямоугольнику (он легко расходится с реальным кадром — тогда
/// на карте пусто). Ограничиваем только числом ближайших к центру — слой кластеризации в [STOOSMMap] тяжёлый на тысячах точек.
List<ExternalPOI> _prioritizeExternalsForMap(List<ExternalPOI> list, LatLng center, {int maxCount = 400}) {
  if (list.length <= maxCount) return list;
  final copy = List<ExternalPOI>.from(list);
  copy.sort((a, b) {
    final da = _distanceKm(a.lat, a.lng, center.latitude, center.longitude);
    final db = _distanceKm(b.lat, b.lng, center.latitude, center.longitude);
    return da.compareTo(db);
  });
  return copy.take(maxCount).toList();
}

/// Bbox из [STOOSMMap] — отбрасываем вырожденные/«глобальные» значения (до layout, сбой камеры).
bool _isPlausibleVisibleMapRect(({double minLat, double minLng, double maxLat, double maxLng}) r) {
  final latSpan = r.maxLat - r.minLat;
  final lngSpan = r.maxLng - r.minLng;
  if (latSpan <= 1e-9 || lngSpan <= 1e-9) return false;
  if (latSpan > 170 || lngSpan > 350) return false;
  return true;
}

/// south/west/north/east из flutter_map — приводим к min≤max (на всякий случай).
({double minLat, double minLng, double maxLat, double maxLng}) _normalizeVisibleBounds(
  double south,
  double west,
  double north,
  double east,
) {
  return (
    minLat: math.min(south, north),
    maxLat: math.max(south, north),
    minLng: math.min(west, east),
    maxLng: math.max(west, east),
  );
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
  /// При фильтре «Мойка»: какие подтипы внешних POI показывать (мультивыбор; по умолчанию — классика).
  Set<WashSubtype> _washSubtypesSelected = {WashSubtype.classic};
  final _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Position? _userPosition;
  bool _locationRequested = false;
  /// При включённой «Сортировать по машине» — false = только точки по выбранной машине, true = показать все.
  bool _showAllOrganizations = false;
  /// Показывать ли на карте недобавленные организации (цветные капли по типу).
  bool _showExternalPOIsOnMap = false;
  /// Фильтр по расстоянию (км), null — не ограничивать. Применяется из модалки «Фильтры».
  double? _maxDistanceKm;
  /// Минимальный рейтинг (например 3.0, 4.0, 4.5), null — любой. Применяется из модалки «Фильтры».
  double? _minRating;
  /// Выбранные ID услуг для фильтра (AND: точка должна оказывать все выбранные услуги).
  List<String> _selectedServiceIds = [];

  /// ISO UTC ближайшего слота по фильтру услуг (ключ — organization id).
  Map<String, String?> _nearestSlotIsoByOrgId = {};
  Timer? _nearestSlotsDebounce;
  String _nearestSlotsFetchKey = '';

  bool _mapReady = false;
  MapController? _osmMapController;

  /// Таймер ожидания геолокации (3 сек): по истечении показываем кнопку «Моё местоположение».
  Timer? _locationWaitTimer;
  bool _showMyLocationButton = false;
  bool _locationWaitTimerStarted = false;

  /// Внешние POI (непартнёрские). Загружаются по видимой области из кэша или Overpass. При 429/ошибке список не очищается.
  List<ExternalPOI> _externalPOIs = [];
  bool _externalPOIsLoading = false;
  Timer? _debounceTimer;
  final _overpassPoi = OverpassPoiService();
  final _externalPoiCache = ExternalPOICache();
  /// Счётчик запросов внешних POI: ответы от устаревших запросов не трогают UI.
  int _externalFetchGeneration = 0;
  Timer? _externalSessionSaveDebounce;

  void _scheduleSaveExternalSession() {
    _externalSessionSaveDebounce?.cancel();
    _externalSessionSaveDebounce = Timer(const Duration(milliseconds: 800), () async {
      if (!mounted || !_showExternalPOIsOnMap || _externalPOIs.isEmpty) return;
      final prefs = await ref.read(sharedPreferencesProvider.future);
      await ExternalPoiSessionStore.save(prefs, _externalPOIs);
    });
  }

  /// Текущий зум карты для масштабирования размера маркеров (меньше при отдалении).
  double _currentZoom = 14.0;
  /// Текущий центр карты (для плавной анимации к выбранной точке).
  LatLng? _lastMapCenter;
  /// Видимый bbox из [MapController.camera.visibleBounds] (не грубая оценка по центру/зуму).
  ({double minLat, double minLng, double maxLat, double maxLng})? _lastVisibleMapRect;

  /// Базовый список точек из API/поиска; затем применяются локальные фильтры (машина, рейтинг, расстояние, услуги).
  /// [skipCarFilter] — чтобы понять, скрыла ли пустой список именно привязка к марке авто.
  List<STO> _getFilteredSTOs(WidgetRef ref, List<STO> baseList, {bool skipCarFilter = false}) {
    var list = List<STO>.from(baseList);
    final serviceFilterIds = normalizeClientServiceFilterIds(_selectedServiceIds);
    if (serviceFilterIds.isNotEmpty) {
      list = list.where((s) => stoMatchesAllCatalogServiceFilters(s, serviceFilterIds)).toList();
      list = list.map((s) {
        var price = 0;
        var duration = 0;
        for (final fid in serviceFilterIds) {
          price += priceKopecksForCatalogFilterLine(s, fid);
          duration += durationMinutesForCatalogFilterLine(s, fid);
        }
        return s.copyWith(totalSelectedPriceKopecks: price, totalSelectedDurationMinutes: duration);
      }).toList();
    }
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      final catData = ref.watch(catalogServicesProvider(null)).valueOrNull;
      list = list.where((s) {
        if (s.name.toLowerCase().contains(query) ||
            s.address.toLowerCase().contains(query) ||
            s.specializations.any((sp) => sp.toLowerCase().contains(query))) {
          return true;
        }
        if (catData == null || catData.items.isEmpty) return false;
        final matchingIds = catData.items
            .where((i) => i.name.toLowerCase().contains(query))
            .map((i) => i.id)
            .toList();
        if (matchingIds.isEmpty) return false;
        final offered = effectiveOfferedServiceIds(s);
        return matchingIds.any((id) => offered.contains(id));
      }).toList();
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

  void _scheduleNearestSlotsPrefetch(WidgetRef ref, List<STO> stos) {
    final sids = normalizeClientServiceFilterIds(_selectedServiceIds);
    if (sids.isEmpty) {
      if (_nearestSlotIsoByOrgId.isNotEmpty || _nearestSlotsFetchKey.isNotEmpty) {
        setState(() {
          _nearestSlotIsoByOrgId = {};
          _nearestSlotsFetchKey = '';
        });
      }
      return;
    }
    final orgKeys = stos.map((s) => s.id).where((x) => x.isNotEmpty).toList()..sort();
    final key = '${sids.join(',')}|${orgKeys.join(',')}';
    if (key == _nearestSlotsFetchKey) return;
    _nearestSlotsDebounce?.cancel();
    _nearestSlotsDebounce = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted) return;
      final api = ref.read(catalogApiServiceProvider);
      final result = await api.nearestSlotsBatch(organizationIds: orgKeys, serviceIds: sids);
      if (!mounted) return;
      result.when(
        success: (data) {
          final raw = data['results'] as List<dynamic>? ?? [];
          final map = <String, String?>{};
          for (final e in raw) {
            if (e is! Map) continue;
            final id = e['organization_id']?.toString() ?? '';
            final ns = e['nearest_start']?.toString();
            if (id.isEmpty) continue;
            map[id] = (ns != null && ns.isNotEmpty) ? ns : null;
          }
          setState(() {
            _nearestSlotIsoByOrgId = map;
            _nearestSlotsFetchKey = key;
          });
        },
        failure: (_) {
          setState(() => _nearestSlotsFetchKey = key);
        },
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _searchFocus.addListener(() => setState(() {}));
  }

  String? _catalogOrgKind(AppL10n l10n) {
    final chips = _mainOrgKindChips(l10n);
    final i = _selectedFilter.clamp(0, chips.length - 1);
    return chips[i].kind;
  }

  Future<void> _showServiceFilterSheet(BuildContext context, WidgetRef ref) async {
    final l10n = L10nScope.of(context);
    final catalog = await ref.read(catalogServicesProvider(_catalogOrgKind(l10n)).future);
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.palette.cardBg,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
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
            setState(() => _selectedServiceIds = normalizeClientServiceFilterIds(ids));
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
    _nearestSlotsDebounce?.cancel();
    _locationWaitTimer?.cancel();
    _debounceTimer?.cancel();
    _externalSessionSaveDebounce?.cancel();
    _searchFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Максимум POI в сессии, чтобы не раздувать память при долгом перемещении по карте.
  static const int _maxSessionPOIs = 1500;
  /// После этого времени кэш на диске ещё валиден, но фоном подтягиваем свежие данные Overpass.
  static const Duration _externalCacheSoftRefreshAfter = Duration(hours: 6);

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

  /// Фоновое обновление области без спиннера (после показа кэша).
  Future<void> _refreshExternalFromNetworkQuiet(
    ({double minLat, double minLng, double maxLat, double maxLng}) ex,
  ) async {
    try {
      final list = await _overpassPoi.searchInBounds(
        minLat: ex.minLat,
        minLng: ex.minLng,
        maxLat: ex.maxLat,
        maxLng: ex.maxLng,
      );
      if (list.isEmpty) return;
      await _externalPoiCache.put(ex.minLat, ex.minLng, ex.maxLat, ex.maxLng, list);
      if (!mounted || !_showExternalPOIsOnMap) return;
      setState(() {
        _externalPOIs = _mergeSessionPOIs(_externalPOIs, list);
      });
      _scheduleSaveExternalSession();
    } catch (_) {}
  }

  static bool _poiInExpandedBounds(ExternalPOI p, ({double minLat, double minLng, double maxLat, double maxLng}) ex) =>
      p.lat >= ex.minLat && p.lat <= ex.maxLat && p.lng >= ex.minLng && p.lng <= ex.maxLng;

  /// Загрузить внешние организации по заданным границам карты.
  /// Сначала диск/память (точный bbox, пересечение областей, сессия), затем при необходимости сеть.
  Future<void> _fetchExternalPOIsForBounds(double minLat, double minLng, double maxLat, double maxLng) async {
    if (!mounted || !_showExternalPOIsOnMap) return;

    final nb = _normalizeVisibleBounds(minLat, minLng, maxLat, maxLng);
    final gen = ++_externalFetchGeneration;
    final ex = _expandBoundsForExternalFetch(nb.minLat, nb.minLng, nb.maxLat, nb.maxLng);

    try {
      await _externalPoiCache.ensureLoaded();

      if (_externalPOIs.isEmpty) {
        final prefs = await ref.read(sharedPreferencesProvider.future);
        final snap = await ExternalPoiSessionStore.load(prefs);
        if (snap != null && snap.isNotEmpty) {
          final inView = snap.where((p) => _poiInExpandedBounds(p, ex)).toList();
          if (inView.isNotEmpty && mounted && gen == _externalFetchGeneration) {
            setState(() {
              _externalPOIs = _mergeSessionPOIs(_externalPOIs, inView);
              _externalPOIsLoading = false;
            });
            _scheduleSaveExternalSession();
          }
        }
      }

      final hit = await _externalPoiCache.lookup(ex.minLat, ex.minLng, ex.maxLat, ex.maxLng);

      if (hit != null) {
        if (mounted && gen == _externalFetchGeneration) {
          setState(() {
            _externalPOIs = _mergeSessionPOIs(_externalPOIs, hit.pois);
            _externalPOIsLoading = false;
          });
          _scheduleSaveExternalSession();
        }
        if (DateTime.now().difference(hit.fetchedAt) > _externalCacheSoftRefreshAfter) {
          unawaited(_refreshExternalFromNetworkQuiet(ex));
        }
        return;
      }

      final mergedHit = await _externalPoiCache.lookupMergeOverlapping(
        ex.minLat,
        ex.minLng,
        ex.maxLat,
        ex.maxLng,
      );
      if (mergedHit != null && mergedHit.pois.isNotEmpty) {
        if (mounted && gen == _externalFetchGeneration) {
          setState(() {
            _externalPOIs = _mergeSessionPOIs(_externalPOIs, mergedHit.pois);
            _externalPOIsLoading = false;
          });
          _scheduleSaveExternalSession();
        }
        if (DateTime.now().difference(mergedHit.fetchedAt) > _externalCacheSoftRefreshAfter) {
          unawaited(_refreshExternalFromNetworkQuiet(ex));
        }
        return;
      }

      if (mounted && gen == _externalFetchGeneration) {
        setState(() => _externalPOIsLoading = _externalPOIs.isEmpty);
      }

      final list = await _overpassPoi.searchInBounds(
        minLat: ex.minLat,
        minLng: ex.minLng,
        maxLat: ex.maxLat,
        maxLng: ex.maxLng,
      );

      if (gen != _externalFetchGeneration) return;

      if (list.isNotEmpty) {
        await _externalPoiCache.put(ex.minLat, ex.minLng, ex.maxLat, ex.maxLng, list);
      }

      if (mounted) {
        setState(() {
          if (list.isNotEmpty) _externalPOIs = _mergeSessionPOIs(_externalPOIs, list);
          _externalPOIsLoading = false;
        });
        if (list.isNotEmpty) _scheduleSaveExternalSession();
      }
    } catch (_) {
      if (mounted && gen == _externalFetchGeneration) {
        setState(() => _externalPOIsLoading = false);
      }
    }
  }

  /// Внешние POI для карты с учётом выбранного фильтра категории.
  List<ExternalPOI> _getFilteredExternalPOIs(AppL10n l10n) {
    final chips = _mainOrgKindChips(l10n);
    final idx = _selectedFilter.clamp(0, chips.length - 1);
    final kind = chips[idx].kind;
    if (kind == null) return _externalPOIs;
    if (kind == 'car_wash') {
      final union = _washExternalMatchUnion(_washSubtypesSelected);
      if (union.isEmpty) return [];
      return _externalPOIs.where((p) => p.types.any(union.contains)).toList();
    }
    final match = _externalMatchForMainKind(kind);
    if (match == null) return _externalPOIs;
    if (match.isEmpty) return [];
    return _externalPOIs.where((p) => p.types.any(match.contains)).toList();
  }

  /// Повторная загрузка внешних POI по текущему центру/зуму (после включения слоя «непартнёрские»).
  void _refetchExternalPoisForCurrentMapView() {
    final rect = _lastVisibleMapRect;
    if (rect != null && _isPlausibleVisibleMapRect(rect)) {
      unawaited(_fetchExternalPOIsForBounds(rect.minLat, rect.minLng, rect.maxLat, rect.maxLng));
      return;
    }
    LatLng? center = _lastMapCenter;
    if (center == null && _osmMapController != null) {
      try {
        center = _osmMapController!.camera.center;
      } catch (_) {}
    }
    center ??= const LatLng(45.0355, 38.9753);
    final zoom = _currentZoom;
    final scale = 180 / (math.pow(2, zoom) * 256);
    final dLat = 0.5 * scale * 256;
    final dLng = scale * 256;
    unawaited(_fetchExternalPOIsForBounds(
      center.latitude - dLat,
      center.longitude - dLng,
      center.latitude + dLat,
      center.longitude + dLng,
    ));
  }

  void _onMapVisibleBounds(double minLat, double minLng, double maxLat, double maxLng) {
    final n = _normalizeVisibleBounds(minLat, minLng, maxLat, maxLng);
    final next = (minLat: n.minLat, minLng: n.minLng, maxLat: n.maxLat, maxLng: n.maxLng);
    final prev = _lastVisibleMapRect;
    const t = 1e-7;
    final changed = prev == null ||
        (prev.minLat - next.minLat).abs() > t ||
        (prev.maxLat - next.maxLat).abs() > t ||
        (prev.minLng - next.minLng).abs() > t ||
        (prev.maxLng - next.maxLng).abs() > t;
    if (changed) {
      _lastVisibleMapRect = next;
      if (mounted) setState(() {});
    }
    if (!_showExternalPOIsOnMap) return;
    unawaited(_fetchExternalPOIsForBounds(next.minLat, next.minLng, next.maxLat, next.maxLng));
  }

  /// Внешние POI для отображения на карте: скрываем только очень близкие к партнёру точки (тот же объект),
  /// иначе при плотной сети партнёров весь слой OSM обнулялся.
  static const double _hideExternalIfNearPartnerKm = 0.02;

  List<ExternalPOI> _getExternalPOIsForMap(List<STO> withCoords, AppL10n l10n) {
    return _getFilteredExternalPOIs(l10n)
        .where((p) => !withCoords.any((s) =>
            _distanceKm(p.lat, p.lng, s.latitude!, s.longitude!) < _hideExternalIfNearPartnerKm))
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

    // Системные анимации / тикеры выключены: не крутим AnimationController (иначе карточка и карта расходятся по времени).
    if (MediaQuery.of(context).disableAnimations || !TickerMode.of(context)) {
      controller.move(target, targetZoom);
      if (mounted) {
        setState(() {
          _lastMapCenter = target;
          _currentZoom = targetZoom;
        });
        if (onComplete != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) onComplete();
          });
        }
      }
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

  bool _sameLatLng(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() < 1e-5 && (a.longitude - b.longitude).abs() < 1e-5;
  }

  /// Только сдвиг центра карты, зум не меняется.
  void _runMapPanAnimation(LatLng from, LatLng to, double zoom, {required VoidCallback onComplete}) {
    final ctrl = _osmMapController;
    if (!_mapReady || ctrl == null) {
      onComplete();
      return;
    }
    if (_sameLatLng(from, to)) {
      onComplete();
      return;
    }
    if (MediaQuery.of(context).disableAnimations || !TickerMode.of(context)) {
      ctrl.move(to, zoom);
      if (mounted) {
        setState(() {
          _lastMapCenter = to;
          _currentZoom = zoom;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) onComplete();
        });
      }
      return;
    }

    final anim = AnimationController(duration: const Duration(milliseconds: 850), vsync: this);
    final curve = CurvedAnimation(parent: anim, curve: Curves.easeInOut);
    final latTween = Tween<double>(begin: from.latitude, end: to.latitude);
    final lngTween = Tween<double>(begin: from.longitude, end: to.longitude);

    void tick() {
      if (!mounted || _osmMapController == null) return;
      _osmMapController!.move(
        LatLng(latTween.evaluate(curve), lngTween.evaluate(curve)),
        zoom,
      );
    }

    anim.addListener(tick);
    anim.addStatusListener((s) {
      if (s != AnimationStatus.completed) return;
      anim.removeListener(tick);
      anim.dispose();
      if (!mounted) return;
      setState(() {
        _lastMapCenter = to;
        _currentZoom = zoom;
      });
      onComplete();
    });
    anim.forward();
  }

  /// Смена масштаба без сдвига географического центра (отближение / приближение).
  void _runMapZoomAtCenterAnimation(LatLng center, double fromZ, double toZ, int durationMs, {required VoidCallback onComplete}) {
    final ctrl = _osmMapController;
    if (!_mapReady || ctrl == null) {
      onComplete();
      return;
    }
    if ((fromZ - toZ).abs() < 0.05) {
      onComplete();
      return;
    }
    if (MediaQuery.of(context).disableAnimations || !TickerMode.of(context)) {
      ctrl.move(center, toZ);
      if (mounted) {
        setState(() {
          _lastMapCenter = center;
          _currentZoom = toZ;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) onComplete();
        });
      }
      return;
    }

    final anim = AnimationController(duration: Duration(milliseconds: durationMs), vsync: this);
    final curve = CurvedAnimation(parent: anim, curve: Curves.easeInOut);
    final zTween = Tween<double>(begin: fromZ, end: toZ);

    void tick() {
      if (!mounted || _osmMapController == null) return;
      _osmMapController!.move(center, zTween.evaluate(curve));
    }

    anim.addListener(tick);
    anim.addStatusListener((s) {
      if (s != AnimationStatus.completed) return;
      anim.removeListener(tick);
      anim.dispose();
      if (!mounted) return;
      setState(() {
        _lastMapCenter = center;
        _currentZoom = toZ;
      });
      onComplete();
    });
    anim.forward();
  }

  /// Плавно смещаем карту к точке и открываем деталь: при нужной «высоте» — только центрирование + пауза;
  /// при слишком сильном приближении — сначала отближение 0.5 с, затем переезд + пауза; иначе — прежняя двухфазная анимация + пауза.
  void _animateToStoAndOpen(STO sto) {
    final initialIds = _selectedServiceIds.isNotEmpty
        ? normalizeClientServiceFilterIds(_selectedServiceIds)
        : null;
    void openDetail() {
      if (!mounted) return;
      pushStoDetailScreen(context, STODetailScreen(sto: sto, initialServiceIds: initialIds));
    }

    if (sto.latitude == null || sto.longitude == null) {
      openDetail();
      return;
    }
    if (!_mapReady || _osmMapController == null) {
      openDetail();
      return;
    }
    final target = LatLng(sto.latitude!, sto.longitude!);
    const targetZoom = 16.0;
    const eps = 0.25;
    final startCenter = _lastMapCenter ?? target;
    final startZoom = _currentZoom;

    if (_sameLatLng(startCenter, target) && (startZoom - targetZoom).abs() < eps) {
      Future.delayed(const Duration(milliseconds: 300), openDetail);
      return;
    }

    if (MediaQuery.of(context).disableAnimations || !TickerMode.of(context)) {
      _osmMapController!.move(target, targetZoom);
      if (mounted) {
        setState(() {
          _lastMapCenter = target;
          _currentZoom = targetZoom;
        });
        Future.delayed(const Duration(milliseconds: 300), openDetail);
      }
      return;
    }

    final sameHeight = (startZoom - targetZoom).abs() < eps;
    final tooZoomedIn = startZoom > targetZoom + eps;

    if (sameHeight) {
      _runMapPanAnimation(startCenter, target, startZoom, onComplete: () {
        Future.delayed(const Duration(milliseconds: 300), openDetail);
      });
      return;
    }

    if (tooZoomedIn) {
      _runMapZoomAtCenterAnimation(startCenter, startZoom, targetZoom, 500, onComplete: () {
        final panFrom = _lastMapCenter ?? startCenter;
        _runMapPanAnimation(panFrom, target, targetZoom, onComplete: () {
          Future.delayed(const Duration(milliseconds: 300), openDetail);
        });
      });
      return;
    }

    _animateMapToCenterAndZoom(target, targetZoom, onComplete: () {
      Future.delayed(const Duration(milliseconds: 300), openDetail);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<String>?>(searchServiceFilterBootstrapProvider, (prev, next) {
      if (next == null || next.isEmpty) return;
      final copy = normalizeClientServiceFilterIds(next);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(searchServiceFilterBootstrapProvider.notifier).state = null;
        setState(() => _selectedServiceIds = copy);
      });
    });

    final l10n = L10nScope.of(context);
    final orgChips = _mainOrgKindChips(l10n);
    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: SizedBox(
                height: 56,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l10n.searchScreenTitle, style: AppTextStyles.screenTitle(context.palette)),
                ),
              ),
            ),
            // Строка поиска + подсказки услуг из каталога (до 2 строк, дальше прокрутка)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: context.palette.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.palette.border),
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: 14),
                        Icon(Icons.search_rounded, size: 22, color: context.palette.textSecondary),
                        SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocus,
                            style: TextStyle(fontSize: 14, color: context.palette.textPrimary),
                            decoration: InputDecoration(
                              hintText: l10n.searchFieldHint,
                              hintStyle: TextStyle(color: context.palette.textPlaceholder, fontSize: 14),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showServiceFilterSheet(context, ref),
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.filter_list_rounded, size: 22, color: context.palette.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final q = _searchController.text.trim();
                      if (q.length < 2 || !_searchFocus.hasFocus) return const SizedBox.shrink();
                      final cat = ref.watch(catalogServicesProvider(null));
                      return cat.when(
                        data: (data) {
                          final ql = q.toLowerCase();
                          final matches = data.items.where((i) => i.name.toLowerCase().contains(ql)).take(40).toList();
                          if (matches.isEmpty) return const SizedBox.shrink();
                          String catName(String catId) {
                            for (final c in data.categories) {
                              if (c.id == catId) return c.name;
                            }
                            return '';
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Material(
                              color: context.palette.cardBg,
                              elevation: 8,
                              shadowColor: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 112),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  itemCount: matches.length,
                                  separatorBuilder: (_, _) => Divider(height: 1, color: context.palette.border),
                                  itemBuilder: (ctx, i) {
                                    final it = matches[i];
                                    final cn = catName(it.categoryId);
                                    return ListTile(
                                      dense: true,
                                      visualDensity: VisualDensity.compact,
                                      title: Text(
                                        it.name,
                                        style: TextStyle(fontSize: 14, color: context.palette.textPrimary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: cn.isEmpty
                                          ? null
                                          : Text(
                                              cn,
                                              style: TextStyle(fontSize: 11, color: context.palette.textSecondary),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                      onTap: () {
                                        final add = normalizeClientServiceFilterIds([it.id]);
                                        var merged = normalizeClientServiceFilterIds([..._selectedServiceIds, ...add]);
                                        if (merged.length > 2) {
                                          merged = merged.sublist(merged.length - 2);
                                        }
                                        setState(() {
                                          _selectedServiceIds = merged;
                                          _searchController.clear();
                                        });
                                        _searchFocus.unfocus();
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      );
                    },
                  ),
                ],
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
                              label: Text(names[id] ?? id, style: TextStyle(fontSize: 12)),
                              deleteIcon: Icon(Icons.close, size: 16),
                              onDeleted: () => setState(() => _selectedServiceIds = _selectedServiceIds.where((x) => x != id).toList()),
                            ),
                          )),
                          TextButton(
                            onPressed: () => setState(() => _selectedServiceIds = []),
                            child: Text(l10n.searchResetAll),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            // Переключатель: Карта / Список (по умолчанию открыта карта)
            GarageTutorialTarget(
              highlightStep: GarageFirstCarTutorialStep.searchMapAndFilters,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.palette.border),
                  ),
                  child: Row(
                    children: [
                      _SegmentBtn(label: l10n.searchViewMap, active: _isMapView,
                        onTap: () => setState(() => _isMapView = true)),
                      _SegmentBtn(label: l10n.searchViewList, active: !_isMapView,
                        onTap: () => setState(() => _isMapView = false)),
                    ],
                  ),
                ),
              ),
            ),
            // Фильтры (главный ряд)
            GarageTutorialTarget(
              highlightStep: GarageFirstCarTutorialStep.bookingHint,
              child: SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: orgChips.length + 1,
                separatorBuilder: (_, _) => SizedBox(width: 8),
                itemBuilder: (_, i) {
                  if (i == orgChips.length) {
                    return GestureDetector(
                      onTap: () => _showFilters(context),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.palette.border),
                        ),
                        child: Icon(Icons.tune_rounded, size: 18, color: context.palette.textSecondary),
                      ),
                    );
                  }
                  final isActive = i == _selectedFilter;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        final prevKind = orgChips[_selectedFilter.clamp(0, orgChips.length - 1)].kind;
                        _selectedFilter = i;
                        final newKind = orgChips[i].kind;
                        if (prevKind == 'car_wash' && newKind != 'car_wash') {
                          _washSubtypesSelected = {WashSubtype.classic};
                        }
                        if (newKind == 'car_wash' && _washSubtypesSelected.isEmpty) {
                          _washSubtypesSelected = {WashSubtype.classic};
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isActive ? context.palette.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isActive ? context.palette.primary : context.palette.border),
                      ),
                      alignment: Alignment.center,
                      child: Text(orgChips[i].label, style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500,
                        color: isActive ? context.palette.onAccent : context.palette.textSecondary,
                      )),
                    ),
                  );
                },
              ),
            ),
            ),
            // Подтипы мойки (справа в том же стиле — вторая строка, только при выбранной «Мойка»)
            Builder(
              builder: (context) {
                final idx = _selectedFilter.clamp(0, orgChips.length - 1);
                if (orgChips[idx].kind != 'car_wash') return const SizedBox.shrink();
                Widget chip(WashSubtype st, String label) {
                  final on = _washSubtypesSelected.contains(st);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_washSubtypesSelected.contains(st)) {
                            if (_washSubtypesSelected.length > 1) _washSubtypesSelected = Set<WashSubtype>.from(_washSubtypesSelected)..remove(st);
                          } else {
                            _washSubtypesSelected = Set<WashSubtype>.from(_washSubtypesSelected)..add(st);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: on ? context.palette.primary.withValues(alpha: 0.2) : context.palette.cardBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: on ? context.palette.primary : context.palette.border),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                            color: on ? context.palette.primary : context.palette.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(left: 16, top: 8, right: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          chip(WashSubtype.classic, l10n.searchWashSubtypeClassic),
                          chip(WashSubtype.selfService, l10n.searchWashSubtypeSelfService),
                          chip(WashSubtype.robot, l10n.searchWashSubtypeRobot),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 12),
            // Контент: список точек с сервера (поиск) + локальные фильтры
            Expanded(
              child: Builder(
                builder: (context) {
                  final searchQuery = _searchController.text.trim();
                  final chipIdx = _selectedFilter.clamp(0, orgChips.length - 1);
                  final businessKind = orgChips[chipIdx].kind;
                  final searchAsync = ref.watch(stoSearchProvider((
                    query: searchQuery.isEmpty ? null : searchQuery,
                    businessKind: businessKind,
                  )));
                  final baseList = searchAsync.valueOrNull ?? [];
                  final list = _getFilteredSTOs(ref, baseList);
                  return _isMapView
                      ? _buildMapView(list, ref, l10n)
                      : _buildList(context, ref, l10n, list, baseList: baseList, searchAsync: searchAsync);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    AppL10n l10n,
    List<STO> stos, {
    required List<STO> baseList,
    required AsyncValue<List<STO>> searchAsync,
  }) {
    if (searchAsync.isLoading && baseList.isEmpty) {
      return Center(child: CircularProgressIndicator(color: context.palette.primary));
    }
    if (searchAsync.hasError && baseList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.searchListLoadError,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: context.palette.textSecondary),
          ),
        ),
      );
    }

    final showShowAllFooter = ref.watch(filterByCarSettingProvider) &&
        ref.watch(selectedCarIdProvider) != null;
    final itemCount = stos.length + (showShowAllFooter ? 1 : 0);

    if (stos.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scheduleNearestSlotsPrefetch(ref, stos);
      });
    }

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
              Icon(Icons.search_off_rounded, size: 64, color: context.palette.textTertiary),
              SizedBox(height: 16),
              Text(
                isServiceFilter
                    ? l10n.searchEmptyAllServices
                    : (hiddenByCarFilter
                        ? l10n.searchEmptyCarBrand
                        : l10n.searchNothingFound),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: context.palette.textSecondary),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                isServiceFilter
                    ? l10n.searchEmptyTryFilters
                    : (hiddenByCarFilter
                        ? l10n.searchEmptyCarFilterHint
                        : l10n.searchEmptyChangeQuery),
                style: TextStyle(fontSize: 14, color: context.palette.textTertiary),
                textAlign: TextAlign.center,
              ),
              if (hiddenByCarFilter) ...[
                SizedBox(height: 16),
                FilledButton(
                  onPressed: () => setState(() => _showAllOrganizations = true),
                  child: Text(l10n.searchShowAll),
                ),
              ],
              if (isServiceFilter) ...[
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => setState(() => _selectedServiceIds = []),
                      child: Text(l10n.searchClearFilter),
                    ),
                    SizedBox(width: 12),
                    FilledButton(
                      onPressed: () => _showServiceFilterSheet(context, ref),
                      child: Text(l10n.searchEditServices),
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
              l10n.searchFoundOrganizations(stos.length),
              style: TextStyle(fontSize: 13, color: context.palette.textSecondary, fontWeight: FontWeight.w500),
            ),
          ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          separatorBuilder: (_, __) => SizedBox(height: 8),
          itemBuilder: (_, i) {
            if (i == stos.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: GestureDetector(
                    onTap: () => setState(() => _showAllOrganizations = !_showAllOrganizations),
                    child: Text(
                      _showAllOrganizations ? l10n.searchHideAll : l10n.searchShowAll,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.palette.primary,
                      ),
                    ),
                  ),
                ),
              );
            }
            final sto = stos[i].copyWith(nearestSlotStartIso: _nearestSlotIsoByOrgId[stos[i].id]);
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
          onTap: () => pushStoDetailScreen(
            context,
            STODetailScreen(
              sto: sto,
              initialServiceIds: _selectedServiceIds.isNotEmpty
                  ? normalizeClientServiceFilterIds(_selectedServiceIds)
                  : null,
            ),
          ),
          onCall: (s) => _openCallForSto(context, s),
          onRoute: (s) => _openRouteToSto(context, s),
          onWrite: (s) => _openChatWithSto(context, s),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMapView(List<STO> stos, WidgetRef ref, AppL10n l10n) {
    if (stos.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scheduleNearestSlotsPrefetch(ref, stos);
      });
    }
    final withCoords = stos
        .map((s) => s.copyWith(nearestSlotStartIso: _nearestSlotIsoByOrgId[s.id]))
        .where((s) => s.latitude != null && s.longitude != null)
        .toList();
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

    final mapCenter = _lastMapCenter ?? initialCenter;
    // Партнёрские точки — все с координатами. Непартнёры — без лишней гео-обрезки по прямоугольнику
    // (она давала пустую карту); только усечение по числу ближайших к центру.
    final externalsOnMap = _showExternalPOIsOnMap
        ? _prioritizeExternalsForMap(_getExternalPOIsForMap(withCoords, l10n), mapCenter)
        : <ExternalPOI>[];
    final showExternalOsmBanner =
        _showExternalPOIsOnMap && !_externalPOIsLoading && externalsOnMap.isEmpty;

    final canUseBrandToggle =
        ref.watch(filterByCarSettingProvider) && ref.watch(selectedCarIdProvider) != null;
    final mapProvider = ref.watch(mapProviderSettingProvider);
    final showExternalMapLauncher =
        mapProvider == MapProvider.google || mapProvider == MapProvider.yandex;
    final hasMapLocButton = _showMyLocationButton || _userPosition != null;
    final mapFabBottom = 8.0 + MediaQuery.of(context).padding.bottom;
    const mapFabStep = 56.0;

    return Stack(
      children: [
        STOOSMMap(
          initialCenter: initialCenter,
          initialZoom: initialZoom,
          partners: withCoords,
          favoriteStoIds: ref.watch(effectiveFavoriteStoIdsProvider),
          externals: externalsOnMap,
          tileUrlTemplate: InAppMapTiles.urlTemplateFor(mapProvider),
          tileSubdomains: InAppMapTiles.subdomainsFor(mapProvider),
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
          onVisibleBoundsChanged: _onMapVisibleBounds,
        ),
        if (_showExternalPOIsOnMap && _externalPOIsLoading)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Material(
                color: context.palette.cardBg.withValues(alpha: 0.92),
                elevation: 1,
                shadowColor: context.palette.shadowDark,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  color: context.palette.primary,
                  backgroundColor: context.palette.brightness == Brightness.dark
                      ? context.palette.border.withValues(alpha: 0.55)
                      : context.palette.strokeSoft.withValues(alpha: 0.65),
                ),
              ),
            ),
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
                        separatorBuilder: (_, _) => SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final sto = recommended[i];
                          final distKm = (userLat != null && userLon != null && sto.latitude != null && sto.longitude != null)
                              ? _distanceKm(userLat, userLon, sto.latitude!, sto.longitude!)
                              : sto.distanceKm;
                          return Material(
                            color: context.palette.cardBg.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () => _animateToStoAndOpen(sto),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    StoListLeadingImage(sto: sto, size: 36, borderRadius: 8),
                                    SizedBox(width: 8),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          sto.name,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: context.palette.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(Icons.star_rounded, size: 12, color: context.palette.primary),
                                            SizedBox(width: 2),
                                            Text(
                                              Formatters.rating(sto.rating),
                                              style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
                                            ),
                                            if (distKm != null) ...[
                                              SizedBox(width: 6),
                                              Text(
                                                Formatters.distance(distKm),
                                                style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                    SizedBox(width: 6),
                                    Material(
                                      color: context.palette.nestedBg,
                                      borderRadius: BorderRadius.circular(8),
                                      child: InkWell(
                                        onTap: () => _openRouteToSto(context, sto),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: EdgeInsets.all(6),
                                          child: Icon(Icons.directions_rounded, size: 18, color: context.palette.primary),
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
                        color: context.palette.cardBg.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(12),
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline_rounded, size: 22, color: context.palette.primary),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  l10n.searchMapNoCoordsHint,
                                  style: TextStyle(fontSize: 13, color: context.palette.textSecondary, height: 1.35),
                                ),
                              ),
                              TextButton(
                                onPressed: () => setState(() => _isMapView = false),
                                child: Text(l10n.searchViewList),
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
        if (showExternalOsmBanner)
          Positioned(
            left: 10,
            right: 10,
            bottom: mapFabBottom + mapFabStep * 3 + 12,
            child: Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(12),
              color: context.palette.cardBg.withValues(alpha: 0.96),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 22, color: context.palette.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.searchExternalOsmEmptyHint,
                        style: TextStyle(fontSize: 13, color: context.palette.textSecondary, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Открыть текущий вид в Google / Яндекс (настройка «Карты» в профиле)
        if (showExternalMapLauncher)
          Positioned(
            right: 8,
            bottom: mapFabBottom + mapFabStep + (hasMapLocButton ? mapFabStep : 0),
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(28),
              color: context.palette.cardBg.withValues(alpha: 0.95),
              child: IconButton(
                onPressed: () {
                  final c = _lastMapCenter ?? initialCenter;
                  launchExternalMapView(
                    provider: mapProvider,
                    center: c,
                    zoom: _currentZoom,
                  );
                },
                icon: Icon(
                  mapProvider == MapProvider.google ? Icons.map_rounded : Icons.explore_rounded,
                  color: context.palette.primary,
                  size: 26,
                ),
                tooltip: mapProvider == MapProvider.google ? l10n.searchOpenInGoogleMaps : l10n.searchOpenInYandexMaps,
              ),
            ),
          ),
        // «Моё местоположение» — над нижним меню слоёв
        if (_showMyLocationButton || _userPosition != null)
          Positioned(
            right: 8,
            bottom: mapFabBottom + mapFabStep,
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(28),
              color: context.palette.cardBg.withValues(alpha: 0.95),
              child: IconButton(
                onPressed: _moveMapToUserLocation,
                icon: Icon(Icons.my_location_rounded, color: context.palette.primary, size: 26),
                tooltip: l10n.searchMyLocation,
              ),
            ),
          ),
        // Меню слоёв карты — у нижнего края (атрибуция OSM перенесена влево на самой карте)
        Positioned(
          right: 8,
          bottom: mapFabBottom,
          child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(28),
              color: context.palette.cardBg.withValues(alpha: 0.95),
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                offset: const Offset(0, -140),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                icon: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(Icons.layers_rounded, color: context.palette.primary, size: 26),
                ),
                onSelected: (value) {
                  if (value == 'external') {
                    setState(() {
                      _showExternalPOIsOnMap = !_showExternalPOIsOnMap;
                      if (!_showExternalPOIsOnMap) {
                        _externalPOIs = [];
                        _externalFetchGeneration++;
                      }
                    });
                    if (_showExternalPOIsOnMap) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _refetchExternalPoisForCurrentMapView();
                      });
                    }
                  }
                  if (value == 'all_orgs' && canUseBrandToggle) {
                    setState(() => _showAllOrganizations = !_showAllOrganizations);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'external',
                    child: Row(
                      children: [
                        Icon(_showExternalPOIsOnMap ? Icons.visibility_off_rounded : Icons.place_rounded, size: 20, color: context.palette.primary),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            _showExternalPOIsOnMap ? l10n.searchHideNonPartners : l10n.searchShowNonPartners,
                            style: TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'all_orgs',
                    enabled: canUseBrandToggle,
                    child: Row(
                      children: [
                        Icon(Icons.directions_car_rounded, size: 20, color: context.palette.primary),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            _showAllOrganizations ? l10n.searchWithCarBrandFilter : l10n.searchWithoutCarBrandFilter,
                            style: TextStyle(fontSize: 14),
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
      ],
    );
  }

  /// Карточка внешней организации: название, типы, адрес, сообщение «не сотрудничает», Позвонить, Маршрут.
  void _showExternalPOICard(BuildContext context, ExternalPOI poi) {
    final l10n = L10nScope.of(context);
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
          decoration: BoxDecoration(
            color: context.palette.cardBg,
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
                        color: context.palette.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    poi.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: context.palette.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (poi.types.isNotEmpty) ...[
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: poi.types
                          .map((t) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: context.palette.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: context.palette.border),
                                ),
                                child: Text(t, style: TextStyle(fontSize: 12, color: context.palette.textSecondary)),
                              ))
                          .toList(),
                    ),
                  ],
                  SizedBox(height: 8),
                  LocationPreviewCard(
                    latitude: poi.lat,
                    longitude: poi.lng,
                    staticAddress: poi.address ?? '',
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    decoration: BoxDecoration(
                      color: context.palette.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.palette.border),
                    ),
                    child: Text(
                      l10n.searchExternalNotPartner,
                      style: TextStyle(fontSize: 13, color: context.palette.textTertiary, height: 1.3),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      if (poi.phone != null && poi.phone!.isNotEmpty)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              _openCallForExternalPOI(context, poi);
                            },
                            icon: Icon(Icons.phone_rounded, size: 18),
                            label: Text(l10n.searchCall),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: context.palette.primary,
                              side: BorderSide(color: context.palette.primary),
                            ),
                          ),
                        ),
                      if (poi.phone != null && poi.phone!.isNotEmpty) SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _openRouteToExternalPOI(context, poi);
                          },
                          icon: Icon(Icons.directions_rounded, size: 18),
                          label: Text(l10n.searchRoute),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.palette.primary,
                            side: BorderSide(color: context.palette.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(l10n.searchClose),
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
    final l10n = L10nScope.of(context);
    if (poi.phone == null || poi.phone!.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.searchNoPhone), behavior: SnackBarBehavior.floating),
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
          SnackBar(content: Text(l10n.searchDialFailed), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _openRouteWithMapLauncher({
    required double destLat,
    required double destLng,
    required String destinationTitle,
  }) async {
    if (!mounted) return;
    await launchDrivingRoute(
      context,
      ref,
      destLat: destLat,
      destLng: destLng,
      destinationTitle: destinationTitle,
      userPosition: _userPosition,
    );
  }

  Future<void> _openRouteToExternalPOI(BuildContext context, ExternalPOI poi) async {
    await _openRouteWithMapLauncher(
      destLat: poi.lat,
      destLng: poi.lng,
      destinationTitle: poi.name,
    );
  }

  Future<void> _openCallForSto(BuildContext context, STO sto) async {
    final l10n = L10nScope.of(context);
    final phones = sto.displayPhones;
    if (phones.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.searchNoPhone), backgroundColor: context.palette.error),
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
          backgroundColor: context.palette.cardBg,
          title: Text(l10n.searchSelectPhone, style: TextStyle(color: context.palette.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: phones
                .map((n) => ListTile(
                      title: Text(Formatters.phone(n), style: TextStyle(color: context.palette.textPrimary)),
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
            SnackBar(content: Text(l10n.searchDialFailed), backgroundColor: context.palette.error),
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

  Future<void> _openChatWithSto(BuildContext context, STO sto) async {
    final phoneNorm =
        (ref.read(authProvider).user?.phone ?? '').replaceAll(RegExp(r'\D'), '');
    if (phoneNorm.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Укажите телефон в профиле, чтобы написать сервису'),
          ),
        );
      }
      return;
    }
    final result = await ref.read(chatRepositoryProvider).openOrganizationChat(sto.id);
    if (!context.mounted) return;
    result.when(
      success: (chat) {
        ref.read(chatsProvider.notifier).loadChats();
        pushCupertino(context, ChatDetailScreen(chat: chat));
      },
      failure: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: context.palette.error,
          ),
        );
      },
    );
  }

  void _showFilters(BuildContext context) {
    final l10n = L10nScope.of(context);
    double tempMaxKm = _maxDistanceKm ?? 50;
    double? tempMinRating = _minRating;
    final ratingOptions = <String, double?>{
      l10n.searchRatingAny: null,
      '3.0+': 3.0,
      '4.0+': 4.0,
      '4.5+': 4.5,
    };

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.palette.cardBg,
      shape: RoundedRectangleBorder(
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
                    Text(l10n.searchFiltersTitle, style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w600, color: context.palette.textPrimary,
                    )),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(Icons.close_rounded, color: context.palette.textSecondary),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                Text(l10n.searchDistanceKm, style: TextStyle(fontSize: 14, color: context.palette.textSecondary)),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: tempMaxKm.clamp(1.0, 50.0),
                        min: 1,
                        max: 50,
                        divisions: 49,
                        activeColor: context.palette.primary,
                        inactiveColor: context.palette.border,
                        onChanged: (v) {
                          tempMaxKm = v;
                          setModalState(() {});
                        },
                      ),
                    ),
                    SizedBox(width: 40, child: Text('${tempMaxKm.round()}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.palette.textPrimary))),
                  ],
                ),
                SizedBox(height: 16),
                Text(l10n.searchMinRating, style: TextStyle(fontSize: 14, color: context.palette.textSecondary)),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: ratingOptions.entries.map((e) {
                    final isSelected = tempMinRating == e.value;
                    return ChoiceChip(
                      label: Text(e.key),
                      selected: isSelected,
                      selectedColor: context.palette.primary,
                      backgroundColor: context.palette.nestedBg,
                      labelStyle: TextStyle(
                        color: isSelected ? context.palette.onAccent : context.palette.textSecondary,
                        fontSize: 13,
                      ),
                      onSelected: (_) {
                        tempMinRating = e.value;
                        setModalState(() {});
                      },
                    );
                  }).toList(),
                ),
                SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          tempMaxKm = 50;
                          tempMinRating = null;
                          setModalState(() {});
                        },
                        child: Text(l10n.searchFiltersReset),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: context.palette.primaryGradient,
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
                            child: Text(l10n.searchFiltersApply, style: TextStyle(
                              fontWeight: FontWeight.w600, color: context.palette.onAccent,
                            )),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
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
            color: active ? context.palette.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(label, style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: active ? context.palette.onAccent : context.palette.textSecondary,
          )),
        ),
      ),
    );
  }
}

/// Оранжевый бейдж: дата слева, интервал по центру, сумма и значок справа.
class _PriceTimeBadge extends StatelessWidget {
  final int priceKopecks;
  final int durationMinutes;
  final String? nearestSlotIsoUtc;

  const _PriceTimeBadge({
    required this.priceKopecks,
    required this.durationMinutes,
    this.nearestSlotIsoUtc,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = Formatters.searchNearestSlotDateFull(nearestSlotIsoUtc);
    final rangeStr = Formatters.searchNearestSlotTimeRange(nearestSlotIsoUtc, durationMinutes);
    final amountPlain = Formatters.moneyRublesPlain(priceKopecks);
    final fallback =
        '${Formatters.durationMinutes(durationMinutes)} · ${Formatters.money(priceKopecks)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE65100),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: dateStr.isEmpty || rangeStr.isEmpty
          ? Text(
              fallback,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
            )
          : Row(
              children: [
                Expanded(
                  flex: 34,
                  child: Text(
                    dateStr,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 42,
                  child: Text(
                    rangeStr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 34,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          amountPlain,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.payments_rounded, size: 15, color: Colors.white),
                    ],
                  ),
                ),
              ],
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
  final void Function(STO)? onWrite;
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
    this.onWrite,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final statusLine = stoSearchCardTodayHoursLine(sto, l10n);
    final openNow = sto.hoursLive != null ? sto.hoursLive!.isPositiveNow : sto.isOpen;
    final openStyleColor = openNow ? context.palette.success : context.palette.error;

    return Container(
      decoration: BoxDecoration(
        color: context.palette.cardBg.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              child: Padding(
                padding: EdgeInsets.all(compact ? 14 : 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 80,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          StoListLeadingImage(sto: sto, size: 80, borderRadius: 12),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, size: 14, color: context.palette.primary),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  '${Formatters.rating(displayRating ?? sto.rating)} (${displayReviewCount ?? sto.reviewCount})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.palette.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: context.palette.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              GestureDetector(
                                onTap: onFavoriteTap,
                                child: Icon(
                                  isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  size: 22,
                                  color: isFavorite ? context.palette.error : context.palette.textTertiary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  sto.address,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: context.palette.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (sto.distanceKm != null)
                                Text(
                                  Formatters.distance(sto.distanceKm!),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: context.palette.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: openStyleColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  statusLine,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: openStyleColor,
                                    height: 1.25,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          StoSearchListBrandsLine(sto: sto),
                          if (sto.minPrice != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              sto.minPrice!,
                              style: TextStyle(
                                fontSize: 14,
                                color: context.palette.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onCall != null || onRoute != null || onWrite != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onCall != null)
                      _ActionChip(icon: Icons.phone_rounded, label: l10n.searchCall, onTap: () => onCall!(sto)),
                    if (onCall != null && (onRoute != null || onWrite != null)) const SizedBox(width: 6),
                    if (onRoute != null)
                      _ActionChip(
                        icon: Icons.directions_rounded,
                        label: l10n.searchRoute,
                        onTap: () => onRoute!(sto),
                      ),
                    if (onRoute != null && onWrite != null) const SizedBox(width: 6),
                    if (onWrite != null)
                      _ActionChip(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: l10n.searchWrite,
                        onTap: () => onWrite!(sto),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (sto.totalSelectedPriceKopecks != null && sto.totalSelectedPriceKopecks! > 0) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Center(
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 520),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.palette.nestedBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.palette.border.withValues(alpha: 0.5)),
                  ),
                  child: _PriceTimeBadge(
                    priceKopecks: sto.totalSelectedPriceKopecks!,
                    durationMinutes: sto.totalSelectedDurationMinutes ?? 0,
                    nearestSlotIsoUtc: sto.nearestSlotStartIso,
                  ),
                ),
              ),
            ),
          ],
        ],
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
      color: context.palette.nestedBg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: context.palette.primary),
              SizedBox(width: 4),
              Text(label, style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.palette.primary,
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
    final l10n = L10nScope.of(context);
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
                Text(l10n.searchServiceFilterTitle, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.palette.textPrimary)),
                const Spacer(),
                TextButton(
                  onPressed: widget.onReset,
                  child: Text(l10n.searchResetAll),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.searchServicesSearchHint,
                prefixIcon: Icon(Icons.search_rounded, size: 22, color: context.palette.textSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                isDense: true,
              ),
            ),
          ),
          if (_selectedIds.isNotEmpty) ...[
            SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ...widget.items.where((i) => _selectedIds.contains(i.id)).map((i) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text(i.name, style: TextStyle(fontSize: 12)),
                      deleteIcon: Icon(Icons.close, size: 16),
                      onDeleted: () => setState(() => _selectedIds.remove(i.id)),
                    ),
                  )),
                ],
              ),
            ),
          ],
          SizedBox(height: 8),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              children: [
                for (final entry in byCategory.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Text(
                      entry.key.isEmpty ? l10n.searchCategoryOther : (widget.categories.where((c) => c.id == entry.key).map((c) => c.name).firstOrNull ?? l10n.searchCategoryServicesFallback),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.palette.textSecondary),
                    ),
                  ),
                  ...entry.value.map((item) => CheckboxListTile(
                    value: _selectedIds.contains(item.id),
                    onChanged: (v) => setState(() {
                      if (v == true) _selectedIds.add(item.id);
                      else _selectedIds.remove(item.id);
                    }),
                    title: Text(item.name, style: TextStyle(fontSize: 14, color: context.palette.textPrimary)),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  )),
                ],
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
            color: context.palette.cardBg,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onReset,
                    child: Text(l10n.searchFiltersReset),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => widget.onApply(_selectedIds.toList()..sort()),
                    child: Text(l10n.searchFiltersApply),
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
