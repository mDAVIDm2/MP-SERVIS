import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/map/in_app_map_tiles.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/external_poi.dart';
import '../../../../shared/models/sto_model.dart';

double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) * math.sin(dLon / 2) * math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return R * c;
}

/// Категории непартнёрских точек — кластеры **не смешивают** мойки с автосервисами и т.д.
enum _ExternalCategory {
  wash,
  tire,
  autoservice,
  other,
}

_ExternalCategory _categoryFromPoiTypes(List<String> types) {
  if (types.any((t) => t.contains('Мойка'))) return _ExternalCategory.wash;
  if (types.any((t) => t == 'Шиномонтаж')) return _ExternalCategory.tire;
  if (types.any((t) => t == 'Автосервис')) return _ExternalCategory.autoservice;
  return _ExternalCategory.other;
}

_ExternalMarkerPalette _paletteForCategory(_ExternalCategory c) {
  switch (c) {
    case _ExternalCategory.wash:
      return const _ExternalMarkerPalette(fill: Color(0xFF1565C0), darkIcon: false);
    case _ExternalCategory.tire:
      return const _ExternalMarkerPalette(fill: Color(0xFF2E7D32), darkIcon: false);
    case _ExternalCategory.autoservice:
      return const _ExternalMarkerPalette(fill: Color(0xFFC62828), darkIcon: false);
    case _ExternalCategory.other:
      return const _ExternalMarkerPalette(fill: Color(0xFFF9A825), darkIcon: true);
  }
}

/// Шаг сетки кластеризации (в градусах): при меньшем зуме ячейка крупнее — точки сливаются.
/// Множитель меньше 1 — ячейка меньше: в кластер попадают только ближе стоящие точки.
double _externalClusterStepDegrees(double zoom) {
  const zRef = 11.0;
  const base = 0.052;
  /// Чуть крупнее ячейка — кластер собирается при чуть более «близком» приближении, чем раньше.
  const tighter = 0.69;
  return tighter * base / math.pow(2, (zoom - zRef).clamp(-1.0, 11.0));
}

/// Кластеры с цифрой только при **отдалении** (zoom строго ниже порога).
/// При приближении сетка отключается — всегда отдельные пины (без «лишних» групп при сильном zoom-in).
/// Порог чуть выше: отдельные пины только при более сильном zoom-in.
const double _externalClusteringOnlyWhenZoomBelow = 13.12;

/// Зум для сетки кластеров: шаг 0.25 — при плавном движении камеры границы ячеек
/// не пересчитываются на каждом кадре, метки не «дрожат».
double _zoomQuantizedForClustering(double z) {
  return (z * 4).round() / 4.0;
}

/// Одна непартнёрская точка или кластер (несколько POI в ячейке **одной категории**).
class _ClusteredExternalView {
  _ClusteredExternalView._({
    required this.category,
    required this.isCluster,
    required this.lat,
    required this.lng,
    required this.labelEntryId,
    this.singlePoi,
    required this.count,
  });

  factory _ClusteredExternalView.single(ExternalPOI p) {
    final cat = _categoryFromPoiTypes(p.types);
    return _ClusteredExternalView._(
      category: cat,
      isCluster: false,
      lat: p.lat,
      lng: p.lng,
      labelEntryId: p.id,
      singlePoi: p,
      count: 1,
    );
  }

  factory _ClusteredExternalView.cluster({
    required _ExternalCategory category,
    required double lat,
    required double lng,
    required int count,
    required String labelEntryId,
  }) {
    return _ClusteredExternalView._(
      category: category,
      isCluster: true,
      lat: lat,
      lng: lng,
      labelEntryId: labelEntryId,
      singlePoi: null,
      count: count,
    );
  }

  final _ExternalCategory category;
  final bool isCluster;
  final double lat;
  final double lng;
  final String labelEntryId;
  final ExternalPOI? singlePoi;
  final int count;
}

List<_ClusteredExternalView> _clusterExternalEntries(
  List<_MapEntry> entries, {
  required _ExternalCategory category,
  required double zoom,
  required double centerLat,
  required double centerLng,
}) {
  if (entries.isEmpty) return [];
  if (zoom >= _externalClusteringOnlyWhenZoomBelow) {
    final out = entries.map((e) => _ClusteredExternalView.single(e.data as ExternalPOI)).toList();
    out.sort((a, b) {
      final da = _distanceKm(centerLat, centerLng, a.lat, a.lng);
      final db = _distanceKm(centerLat, centerLng, b.lat, b.lng);
      return da.compareTo(db);
    });
    return out;
  }
  final step = _externalClusterStepDegrees(zoom);
  final bins = <String, List<_MapEntry>>{};
  final prefix = '${category.name}_';
  for (final e in entries) {
    final gx = (e.lat / step).floor();
    final gy = (e.lng / step).floor();
    final key = '$prefix$gx|$gy';
    bins.putIfAbsent(key, () => []).add(e);
  }
  final out = <_ClusteredExternalView>[];
  for (final bin in bins.entries) {
    final list = bin.value;
    if (list.length == 1) {
      out.add(_ClusteredExternalView.single(list.first.data as ExternalPOI));
    } else if (list.length == 2) {
      for (final e in list) {
        out.add(_ClusteredExternalView.single(e.data as ExternalPOI));
      }
    } else {
      var sl = 0.0;
      var sn = 0.0;
      for (final x in list) {
        sl += x.lat;
        sn += x.lng;
      }
      final n = list.length;
      out.add(_ClusteredExternalView.cluster(
        category: category,
        lat: sl / n,
        lng: sn / n,
        count: n,
        labelEntryId: 'cl_${bin.key}',
      ));
    }
  }
  out.sort((a, b) {
    final da = _distanceKm(centerLat, centerLng, a.lat, a.lng);
    final db = _distanceKm(centerLat, centerLng, b.lat, b.lng);
    return da.compareTo(db);
  });
  return out;
}

/// Разбиваем точки по категориям и кластеризуем каждую группу отдельно.
List<_ClusteredExternalView> _clusterAllExternalByCategory(
  List<_MapEntry> allExternal, {
  required double zoom,
  required double centerLat,
  required double centerLng,
}) {
  final byCat = <_ExternalCategory, List<_MapEntry>>{
    for (final c in _ExternalCategory.values) c: <_MapEntry>[],
  };
  for (final e in allExternal) {
    final poi = e.data as ExternalPOI;
    byCat[_categoryFromPoiTypes(poi.types)]!.add(e);
  }
  const capPerCategory = 55;
  final merged = <_ClusteredExternalView>[];
  for (final c in _ExternalCategory.values) {
    final list = byCat[c]!;
    if (list.isEmpty) continue;
    var part = _clusterExternalEntries(
      list,
      category: c,
      zoom: zoom,
      centerLat: centerLat,
      centerLng: centerLng,
    );
    if (part.length > capPerCategory) {
      part = part.sublist(0, capPerCategory);
    }
    merged.addAll(part);
  }
  merged.sort((a, b) {
    final da = _distanceKm(centerLat, centerLng, a.lat, a.lng);
    final db = _distanceKm(centerLat, centerLng, b.lat, b.lng);
    return da.compareTo(db);
  });
  return merged;
}

/// Callback с границами видимой области: minLat, minLng, maxLat, maxLng.
typedef VisibleBoundsCallback = void Function(double minLat, double minLng, double maxLat, double maxLng);

/// Карта на OpenStreetMap (бесплатно). Те же колбэки, что и у прежней карты.
class STOOSMMap extends StatefulWidget {
  final LatLng initialCenter;
  final double initialZoom;
  final List<STO> partners;
  /// id организаций в избранном (эффективный набор) — на карте не зелёный пин, а силуэт сердца.
  final Set<String> favoriteStoIds;
  final List<ExternalPOI> externals;
  final LatLng? userLocation;
  final void Function(STO) onPartnerTap;
  final void Function(ExternalPOI) onExternalTap;
  final VoidCallback? onMapReady;
  final void Function(double zoom)? onCameraMove;
  /// Центр и зум при изменении камеры (для плавной анимации к выбранной точке).
  final void Function(LatLng center, double zoom)? onCameraChanged;
  final void Function(MapController controller)? onControllerReady;
  final VisibleBoundsCallback? onVisibleBoundsChanged;
  /// Шаблон тайлов (по умолчанию Carto Voyager).
  final String tileUrlTemplate;
  final List<String> tileSubdomains;

  const STOOSMMap({
    super.key,
    required this.initialCenter,
    this.initialZoom = 14,
    required this.partners,
    this.favoriteStoIds = const <String>{},
    required this.externals,
    this.userLocation,
    required this.onPartnerTap,
    required this.onExternalTap,
    this.onMapReady,
    this.onCameraMove,
    this.onCameraChanged,
    this.onControllerReady,
    this.onVisibleBoundsChanged,
    this.tileUrlTemplate = InAppMapTiles.voyagerTemplate,
    this.tileSubdomains = InAppMapTiles.voyagerSubdomains,
  });

  @override
  State<STOOSMMap> createState() => _STOOSMMapState();
}

class _STOOSMMapState extends State<STOOSMMap> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  /// Плавное «раскрытие» кластера при тапе (анимация зума + покадровое обновление кластеров).
  AnimationController? _clusterExpandController;
  /// Центр/зум для кластеризации непартнёров (синхронно с камерой при движении карты).
  double _clusterZoom = 14;
  LatLng _clusterCenter = const LatLng(45.0355, 38.9753);
  bool _ready = false;
  Timer? _boundsDebounce;
  static const Duration _boundsDebounceDuration = Duration(milliseconds: 100);
  /// Синхронизация layout кластеров с камерой: не чаще [ _clusterSyncMinInterval ] (throttle, не debounce —
  /// иначе при непрерывном зуме обновление было бы только после остановки).
  DateTime? _lastClusterSyncTime;
  static const Duration _clusterSyncMinInterval = Duration(milliseconds: 100);
  static const double _labelZoomThreshold = 15.0;
  static const int _maxLabels = 12;
  /// Партнёры и итоговые кластеры/точки (непартнёрские после кластеризации).
  static const int _maxPartnerMarkers = 130;
  static const int _maxExternalVisuals = 200;

  /// При отдалении маркеры остаются маленькими точками (экранный размер), иначе «закрывают» карту.
  static double _markerSizeFactor(double zoom) {
    const zLo = 9.0;
    const zHi = 15.0;
    const minF = 0.26;
    const maxF = 1.0;
    if (zoom >= zHi) return maxF;
    if (zoom <= zLo) return minF;
    return minF + (zoom - zLo) / (zHi - zLo) * (maxF - minF);
  }

  /// Диаметр круглой «шапки» партнёрского маркера, см. [_PartnerMarkerWidget] `_basePin`.
  static double _partnerPinScreenPx(double sizeFactor) {
    const base = 40.0;
    return (base * sizeFactor).clamp(10.0, base);
  }

  List<Marker>? _cachedMarkers;
  int _cachedPartnersLength = -1;
  int _cachedExternalsLength = -1;
  double _cachedCenterLat = double.nan;
  double _cachedCenterLng = double.nan;
  double _cachedZoom = double.nan;
  bool _cachedHasUserLocation = false;

  @override
  void initState() {
    super.initState();
    _clusterCenter = widget.initialCenter;
    _clusterZoom = widget.initialZoom;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      widget.onControllerReady?.call(_mapController);
      widget.onMapReady?.call();
      _notifyVisibleBounds();
    });
  }

  @override
  void dispose() {
    _clusterExpandController?.dispose();
    _boundsDebounce?.cancel();
    super.dispose();
  }

  void _cancelClusterExpandAnimation() {
    final c = _clusterExpandController;
    if (c == null) return;
    c.dispose();
    _clusterExpandController = null;
  }

  /// Тап по круглому кластеру: плавно и центр, и зум (без скачка в точку кластера).
  void _animateClusterExpand(LatLng target) {
    _cancelClusterExpandAnimation();

    final startCenter = _mapController.camera.center;
    final startZ = _mapController.camera.zoom;
    var endZ = (startZ + 1.35).clamp(4.0, 18.0);
    if ((endZ - startZ).abs() < 0.03) {
      endZ = startZ;
    }
    const eps = 1.2e-6;
    final hasPan = (startCenter.latitude - target.latitude).abs() > eps ||
        (startCenter.longitude - target.longitude).abs() > eps;
    final hasZoom = (endZ - startZ).abs() > 0.0005;
    if (!hasPan && !hasZoom) return;

    if (!mounted) return;
    final mq = MediaQuery.maybeOf(context);
    if (mq != null && (mq.disableAnimations || !TickerMode.of(context))) {
      _mapController.move(target, hasZoom ? endZ : startZ);
      setState(() {
        _clusterCenter = target;
        _clusterZoom = hasZoom ? endZ : startZ;
      });
      return;
    }

    final dKm = _distanceKm(
      startCenter.latitude,
      startCenter.longitude,
      target.latitude,
      target.longitude,
    );
    final extraMs = (dKm * 95).round().clamp(0, 480);
    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1050 + extraMs),
    );
    _clusterExpandController = controller;

    void tick() {
      if (!mounted) return;
      final t = Curves.easeInOutCubic.transform(controller.value);
      final lat = startCenter.latitude + (target.latitude - startCenter.latitude) * t;
      final lng = startCenter.longitude + (target.longitude - startCenter.longitude) * t;
      final z = startZ + (endZ - startZ) * t;
      _mapController.move(LatLng(lat, lng), z);
      // onPositionChanged при программном move не всегда идёт каждый кадр — подтягиваем кластер с троттлингом.
      _throttledSyncClusterFromCamera();
    }

    void onStatus(AnimationStatus status) {
      if (status != AnimationStatus.completed) return;
      controller.removeListener(tick);
      controller.removeStatusListener(onStatus);
      _clusterExpandController = null;
      controller.dispose();
      if (!mounted) return;
      try {
        final cam = _mapController.camera;
        setState(() {
          _clusterCenter = cam.center;
          _clusterZoom = cam.zoom;
        });
        _lastClusterSyncTime = DateTime.now();
      } catch (_) {}
    }

    controller.addListener(tick);
    controller.addStatusListener(onStatus);
    controller.forward();
  }

  void _onPositionChanged(MapCamera position, bool hasGesture) {
    if (!mounted) return;
    if (hasGesture) {
      _cancelClusterExpandAnimation();
    }
    final newCenter = position.center;
    final newZoom = position.zoom;
    widget.onCameraMove?.call(newZoom);
    widget.onCameraChanged?.call(newCenter, newZoom);
    _boundsDebounce?.cancel();
    _boundsDebounce = Timer(_boundsDebounceDuration, _notifyVisibleBounds);

    _throttledSyncClusterFromCamera();
  }

  void _throttledSyncClusterFromCamera() {
    final now = DateTime.now();
    if (_lastClusterSyncTime != null &&
        now.difference(_lastClusterSyncTime!) < _clusterSyncMinInterval) {
      return;
    }
    _lastClusterSyncTime = now;
    if (!mounted) return;
    try {
      final cam = _mapController.camera;
      if (cam.nonRotatedSize == MapCamera.kImpossibleSize) return;
      setState(() {
        _clusterCenter = cam.center;
        _clusterZoom = cam.zoom;
      });
    } catch (_) {}
  }

  void _notifyVisibleBounds() {
    if (!mounted) return;
    final cb = widget.onVisibleBoundsChanged;
    if (cb == null) return;
    try {
      final cam = _mapController.camera;
      // До первого layout размер (-1,-1) — visibleBounds даёт мусор и ломает bbox для Overpass.
      if (cam.nonRotatedSize == MapCamera.kImpossibleSize) return;
      final b = cam.visibleBounds;
      if (mounted) cb(b.south, b.west, b.north, b.east);
    } catch (_) {}
  }

  /// Подпись по партнёрам: при смене выбранных услуг (цены на маркерах) кэш маркеров нужно сбросить.
  int _partnersPriceSignature() {
    return widget.partners.fold<int>(
      0,
      (s, p) =>
          s ^
          (p.id.hashCode +
              (p.totalSelectedPriceKopecks ?? 0) +
              (p.nearestSlotStartIso?.hashCode ?? 0)),
    );
  }

  int _cachedPriceSignature = 0;
  int _cachedFavoritesSignature = 0;

  int _favoritesSignature() {
    if (widget.favoriteStoIds.isEmpty) return 0;
    return widget.favoriteStoIds.fold<int>(0, (a, id) => a ^ id.hashCode) ^
        (widget.favoriteStoIds.length * 100003);
  }

  bool _shouldRebuildMarkers() {
    final pl = widget.partners.length;
    final el = widget.externals.length;
    final hasUser = widget.userLocation != null;
    final priceSig = _partnersPriceSignature();
    final favSig = _favoritesSignature();
    if (pl != _cachedPartnersLength || el != _cachedExternalsLength ||
        _clusterCenter.latitude != _cachedCenterLat || _clusterCenter.longitude != _cachedCenterLng ||
        _clusterZoom != _cachedZoom || hasUser != _cachedHasUserLocation ||
        priceSig != _cachedPriceSignature || favSig != _cachedFavoritesSignature) {
      _cachedPartnersLength = pl;
      _cachedExternalsLength = el;
      _cachedCenterLat = _clusterCenter.latitude;
      _cachedCenterLng = _clusterCenter.longitude;
      _cachedZoom = _clusterZoom;
      _cachedHasUserLocation = hasUser;
      _cachedPriceSignature = priceSig;
      _cachedFavoritesSignature = favSig;
      return true;
    }
    return false;
  }

  List<Marker> _buildMarkers() {
    if (!_shouldRebuildMarkers() && _cachedMarkers != null) return _cachedMarkers!;
    try {
      final showLabels = _clusterZoom >= _labelZoomThreshold;
      final centerLat = _clusterCenter.latitude;
      final centerLng = _clusterCenter.longitude;

      final partnerEntries = widget.partners
          .where((s) => s.latitude != null && s.longitude != null)
          .map((s) => _MapEntry(s.latitude!, s.longitude!, id: s.id, name: s.name, isPartner: true, data: s))
          .toList();
      final externalEntries = widget.externals
          .map((e) => _MapEntry(e.lat, e.lng, id: e.id, name: e.name, isPartner: false, data: e))
          .toList();
      partnerEntries.sort((a, b) {
        final dA = _distanceKm(centerLat, centerLng, a.lat, a.lng);
        final dB = _distanceKm(centerLat, centerLng, b.lat, b.lng);
        return dA.compareTo(dB);
      });
      externalEntries.sort((a, b) {
        final dA = _distanceKm(centerLat, centerLng, a.lat, a.lng);
        final dB = _distanceKm(centerLat, centerLng, b.lat, b.lng);
        return dA.compareTo(dB);
      });
      final partnerLimit = math.min(partnerEntries.length, _maxPartnerMarkers);
      final visiblePartners =
          partnerEntries.length > partnerLimit ? partnerEntries.sublist(0, partnerLimit) : partnerEntries;
      final layoutZoom = _zoomQuantizedForClustering(_clusterZoom);
      var externalVisuals = _clusterAllExternalByCategory(
        externalEntries,
        zoom: layoutZoom,
        centerLat: centerLat,
        centerLng: centerLng,
      );
      if (externalVisuals.length > _maxExternalVisuals) {
        externalVisuals = externalVisuals.sublist(0, _maxExternalVisuals);
      }
      final withLabelIds = showLabels
          ? [
              ...visiblePartners.take(_maxLabels).map((e) => e.id),
              ...externalVisuals.take(_maxLabels).map((v) => v.labelEntryId),
            ].take(_maxLabels).toSet()
          : <String>{};

      final zf = _markerSizeFactor(_clusterZoom);
      final List<Marker> markers = [];
      for (final v in externalVisuals) {
        if (v.isCluster) {
          final pal = _paletteForCategory(v.category);
          final ext = _ExternalClusterBubble.layoutExtent(
            count: v.count,
            sizeFactor: zf,
          );
          markers.add(Marker(
            point: LatLng(v.lat, v.lng),
            width: ext.width,
            height: ext.height,
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () => _animateClusterExpand(LatLng(v.lat, v.lng)),
              child: _ExternalClusterBubble(
                count: v.count,
                sizeFactor: zf,
                palette: pal,
              ),
            ),
          ));
        } else {
          final poi = v.singlePoi!;
          final showLabel = withLabelIds.contains(poi.id);
          final ext = _TeardropPinWidget.layoutExtent(showLabel: showLabel, name: poi.name, sizeFactor: zf);
          markers.add(Marker(
            point: LatLng(poi.lat, poi.lng),
            width: ext.width,
            height: ext.height,
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () => widget.onExternalTap(poi),
              child: _TeardropPinWidget(showLabel: showLabel, name: poi.name, types: poi.types, sizeFactor: zf),
            ),
          ));
        }
      }
      for (final entry in visiblePartners) {
          final sto = entry.data as STO;
          final showLabel = withLabelIds.contains(sto.id);
          final showBadge = sto.totalSelectedPriceKopecks != null && sto.totalSelectedPriceKopecks! > 0;
          final hasNearestSlot = sto.nearestSlotStartIso != null &&
              sto.nearestSlotStartIso!.trim().isNotEmpty &&
              showBadge;
          final isFavorite = widget.favoriteStoIds.contains(sto.id);
          final imageUrl = (sto.logoUrl != null && sto.logoUrl!.isNotEmpty)
              ? sto.logoUrl
              : (sto.photoUrls.isNotEmpty ? sto.photoUrls.first : null);
          final part = _PartnerMarkerWidget.layoutExtent(
            showLabel: showLabel,
            name: sto.name,
            showBadge: showBadge,
            sizeFactor: zf,
          );
          markers.add(Marker(
            point: LatLng(sto.latitude!, sto.longitude!),
            width: part.width,
            height: part.height,
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () => widget.onPartnerTap(sto),
              child: _PartnerMarkerWidget(
                imageUrl: imageUrl,
                showLabel: showLabel,
                name: sto.name,
                isFavorite: isFavorite,
                totalSelectedPriceKopecks: sto.totalSelectedPriceKopecks,
                totalSelectedDurationMinutes: sto.totalSelectedDurationMinutes,
                nearestSlotIsoUtc: hasNearestSlot ? sto.nearestSlotStartIso : null,
                sizeFactor: zf,
              ),
            ),
          ));
      }
      if (widget.userLocation != null) {
        final u = widget.userLocation!;
        markers.add(Marker(
          point: LatLng(u.latitude, u.longitude),
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.withValues(alpha: 0.7),
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ));
      }
      _cachedMarkers = markers;
      return markers;
    } catch (_) {
      _cachedMarkers = [];
      _cachedPartnersLength = widget.partners.length;
      _cachedExternalsLength = widget.externals.length;
      _cachedCenterLat = _clusterCenter.latitude;
      _cachedCenterLng = _clusterCenter.longitude;
      _cachedZoom = _clusterZoom;
      _cachedHasUserLocation = widget.userLocation != null;
      return _cachedMarkers!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: widget.initialCenter,
          initialZoom: widget.initialZoom,
          onPositionChanged: _onPositionChanged,
          onMapReady: _ready ? null : () {},
        ),
        children: [
          TileLayer(
            urlTemplate: widget.tileUrlTemplate,
            subdomains: widget.tileSubdomains,
            userAgentPackageName: 'ru.mpservis.client',
          ),
          MarkerLayer(markers: _buildMarkers()),
          RichAttributionWidget(
            alignment: AttributionAlignment.bottomLeft,
            animationConfig: const ScaleRAWA(),
            showFlutterMapAttribution: false,
            attributions: InAppMapTiles.attributions(),
          ),
        ],
      ),
    );
  }
}

class _MapEntry {
  final double lat;
  final double lng;
  final String id;
  final String name;
  final bool isPartner;
  final dynamic data;
  _MapEntry(this.lat, this.lng, {required this.id, required this.name, required this.isPartner, required this.data});
}

class _LayoutExtent {
  final double width;
  final double height;
  const _LayoutExtent(this.width, this.height);
}

/// Стиль заливки и контраста иконки для непартнёрской точки.
class _ExternalMarkerPalette {
  const _ExternalMarkerPalette({required this.fill, required this.darkIcon});
  final Color fill;
  /// true — тёмная иконка (на жёлтом фоне).
  final bool darkIcon;
}

/// СТО — красный, мойки — синий, шиномонтаж — зелёный, остальные категории — жёлтый.
_ExternalMarkerPalette _paletteForExternalTypes(List<String> types) {
  if (types.any((t) => t.contains('Мойка'))) {
    return const _ExternalMarkerPalette(fill: Color(0xFF1565C0), darkIcon: false);
  }
  if (types.any((t) => t == 'Шиномонтаж')) {
    return const _ExternalMarkerPalette(fill: Color(0xFF2E7D32), darkIcon: false);
  }
  if (types.any((t) => t == 'Автосервис')) {
    return const _ExternalMarkerPalette(fill: Color(0xFFC62828), darkIcon: false);
  }
  return const _ExternalMarkerPalette(fill: Color(0xFFF9A825), darkIcon: true);
}

/// Кластер непартнёрских точек одной категории: цвет как у маркера; тап — приблизить карту.
class _ExternalClusterBubble extends StatelessWidget {
  final int count;
  final double sizeFactor;
  final _ExternalMarkerPalette palette;

  const _ExternalClusterBubble({
    required this.count,
    this.sizeFactor = 1.0,
    required this.palette,
  });

  static _LayoutExtent layoutExtent({required int count, required double sizeFactor}) {
    final cap = _STOOSMMapState._partnerPinScreenPx(sizeFactor);
    // Не больше партнёрского пина: раньше clamp(30,46) при мелком зуме давал 30px при пине ~10px.
    final s = math.min(42 * sizeFactor, cap).clamp(12.0, cap);
    return _LayoutExtent(s, s);
  }

  @override
  Widget build(BuildContext context) {
    final cap = _STOOSMMapState._partnerPinScreenPx(sizeFactor);
    final s = math.min(42 * sizeFactor, cap).clamp(12.0, cap);
    final font = (13 * sizeFactor * (s / 42).clamp(0.65, 1.0)).clamp(8.0, 14.0);
    final txt = count > 99 ? '99+' : '$count';
    final borderW = math.max(1.8, 2.2 * sizeFactor);
    return SizedBox(
      width: s,
      height: s,
      child: Material(
        color: palette.fill,
        shape: CircleBorder(side: BorderSide(color: Colors.white, width: borderW)),
        elevation: 4,
        shadowColor: Colors.black38,
        child: Center(
          child: Text(
            txt,
            style: TextStyle(
              color: palette.darkIcon ? const Color(0xFF263238) : Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: font,
            ),
          ),
        ),
      ),
    );
  }
}

/// Непартнёрские точки: округлая «шапка» + сужение к острию (не «глаз»), остриё на координате ([Marker.alignment] = bottomCenter).
class _TeardropPinWidget extends StatelessWidget {
  final bool showLabel;
  final String name;
  final List<String> types;
  final double sizeFactor;

  const _TeardropPinWidget({
    required this.showLabel,
    required this.name,
    this.types = const [],
    this.sizeFactor = 1.0,
  });

  static const double _baseW = 19.0;
  static const double _baseH = 26.0;
  static const double _baseLabelW = 44.0;

  static _LayoutExtent layoutExtent({required bool showLabel, required String name, required double sizeFactor}) {
    final wDrop = (_baseW * sizeFactor).clamp(10.0, _baseW);
    final hDrop = (_baseH * sizeFactor).clamp(14.0, _baseH);
    final labelW = (_baseLabelW * sizeFactor).clamp(24.0, _baseLabelW);
    final gap = 3 * sizeFactor;
    final labelLine = (11 * sizeFactor).clamp(8.0, 11.0);
    final labelBlock = showLabel && name.isNotEmpty ? labelLine + gap : 0.0;
    final totalW = showLabel && name.isNotEmpty ? math.max(wDrop, labelW) : wDrop;
    final totalH = hDrop + labelBlock;
    return _LayoutExtent(totalW, totalH);
  }

  static IconData _iconForTypes(List<String> types) {
    if (types.any((t) => t.contains('Мойка'))) return Icons.water_drop_rounded;
    if (types.contains('Шиномонтаж')) return Icons.tire_repair_rounded;
    return Icons.build_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final palette = _paletteForExternalTypes(types);
    final icon = _iconForTypes(types);
    final wDrop = (_baseW * sizeFactor).clamp(10.0, _baseW);
    final hDrop = (_baseH * sizeFactor).clamp(14.0, _baseH);
    final labelW = (_baseLabelW * sizeFactor).clamp(24.0, _baseLabelW);
    final gap = 3 * sizeFactor;
    final iconSize = (11 * sizeFactor).clamp(6.0, 11.0);
    final fontSize = (8 * sizeFactor).clamp(6.0, 8.0);
    final iconColor = palette.darkIcon ? const Color(0xFF263238) : Colors.white;

    final drop = SizedBox(
      width: wDrop,
      height: hDrop,
      child: CustomPaint(
        painter: _BulbTaperPinPainter(
          fill: palette.fill,
          border: Colors.white,
          borderWidth: math.max(0.85, 1.05 * sizeFactor),
        ),
        child: Align(
          alignment: const Alignment(0, -0.74),
          child: Icon(icon, color: iconColor, size: iconSize),
        ),
      ),
    );

    if (!showLabel || name.isEmpty) {
      return drop;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: math.max(wDrop, labelW),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: fontSize, color: Colors.black, fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(height: gap),
        drop,
      ],
    );
  }
}

/// Круглая верхняя часть (дуга) + плавное сужение к нижнему острию.
class _BulbTaperPinPainter extends CustomPainter {
  final Color fill;
  final Color border;
  final double borderWidth;

  _BulbTaperPinPainter({
    required this.fill,
    required this.border,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;
    final headR = w * 0.46;
    final headCy = headR;

    final path = ui.Path();
    path.moveTo(cx, h);
    path.cubicTo(
      cx + headR * 1.06,
      h * 0.42,
      cx + headR * 0.98,
      headCy + headR * 0.06,
      cx + headR,
      headCy,
    );
    path.arcTo(
      Rect.fromCircle(center: Offset(cx, headCy), radius: headR),
      0,
      -math.pi,
      false,
    );
    path.cubicTo(
      cx - headR * 0.98,
      headCy + headR * 0.06,
      cx - headR * 1.06,
      h * 0.42,
      cx,
      h,
    );
    path.close();

    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.26), 2.0, false);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _BulbTaperPinPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.border != border || oldDelegate.borderWidth != borderWidth;
}

/// Силуэт сердца для пина избранной организации; путь в координатах [size].
ui.Path _mapPartnerHeartPath(Size size) {
  final w = size.width;
  final h = size.height;
  final p = ui.Path();
  p.moveTo(0.5 * w, 0.90 * h);
  p.cubicTo(0.1 * w, 0.68 * h, 0, 0.45 * h, 0, 0.30 * h);
  p.cubicTo(0, 0.10 * h, 0.20 * w, 0, 0.40 * w, 0.12 * h);
  p.cubicTo(0.45 * w, 0.14 * h, 0.48 * w, 0.20 * h, 0.5 * w, 0.28 * h);
  p.cubicTo(0.52 * w, 0.20 * h, 0.55 * w, 0.14 * h, 0.6 * w, 0.12 * h);
  p.cubicTo(0.80 * w, 0, 1.0 * w, 0.10 * h, 1.0 * w, 0.30 * h);
  p.cubicTo(1.0 * w, 0.45 * h, 0.9 * w, 0.68 * h, 0.5 * w, 0.90 * h);
  p.close();
  return p;
}

class _MapHeartShapeClipper extends CustomClipper<ui.Path> {
  @override
  ui.Path getClip(Size size) => _mapPartnerHeartPath(size);

  @override
  bool shouldReclip(covariant _MapHeartShapeClipper oldClipper) => false;
}

class _MapHeartDropShadowPainter extends CustomPainter {
  const _MapHeartDropShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = _mapPartnerHeartPath(size);
    canvas.drawShadow(
      path,
      Colors.black.withValues(alpha: 0.38),
      math.max(2.0, size.shortestSide * 0.07),
      true,
    );
  }

  @override
  bool shouldRepaint(covariant _MapHeartDropShadowPainter oldDelegate) => false;
}

class _MapHeartEdgePainter extends CustomPainter {
  _MapHeartEdgePainter({required this.borderW, required this.color});

  final double borderW;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _mapPartnerHeartPath(size);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderW
      ..isAntiAlias = true;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MapHeartEdgePainter o) => o.borderW != borderW || o.color != color;
}

class _PartnerSlotBadgeRow extends StatelessWidget {
  const _PartnerSlotBadgeRow({
    required this.sizeFactor,
    required this.priceKopecks,
    required this.durationMinutes,
    this.nearestSlotIsoUtc,
  });

  final double sizeFactor;
  final int priceKopecks;
  final int durationMinutes;
  final String? nearestSlotIsoUtc;

  @override
  Widget build(BuildContext context) {
    final fs = (7.5 * sizeFactor).clamp(6.5, 8.5);
    final dateStr = Formatters.searchNearestSlotDateFull(nearestSlotIsoUtc);
    final rangeStr = Formatters.searchNearestSlotTimeRange(nearestSlotIsoUtc, durationMinutes);
    final amount = Formatters.moneyRublesPlain(priceKopecks);
    final fallback =
        '${Formatters.durationMinutes(durationMinutes)} · ${Formatters.money(priceKopecks)}';

    if (dateStr.isEmpty || rangeStr.isEmpty) {
      return Text(
        fallback,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: fs, fontWeight: FontWeight.w600, color: Colors.white),
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 34,
          child: Text(
            dateStr,
            style: TextStyle(fontSize: fs, fontWeight: FontWeight.w600, color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          flex: 42,
          child: Text(
            rangeStr,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: fs, fontWeight: FontWeight.w600, color: Colors.white),
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
                  amount,
                  style: TextStyle(fontSize: fs, fontWeight: FontWeight.w600, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
              SizedBox(width: 2 * sizeFactor),
              Icon(Icons.payments_rounded, size: (fs + 2).clamp(8.0, 11.0), color: Colors.white),
            ],
          ),
        ),
      ],
    );
  }
}

class _PartnerMarkerWidget extends StatelessWidget {
  final String? imageUrl;
  final bool showLabel;
  final String name;
  /// Избранная организация: красное «заполненное» сердце с фото, не зелёный круг.
  final bool isFavorite;
  final int? totalSelectedPriceKopecks;
  final int? totalSelectedDurationMinutes;
  final String? nearestSlotIsoUtc;
  final double sizeFactor;

  const _PartnerMarkerWidget({
    this.imageUrl,
    required this.showLabel,
    required this.name,
    this.isFavorite = false,
    this.totalSelectedPriceKopecks,
    this.totalSelectedDurationMinutes,
    this.nearestSlotIsoUtc,
    this.sizeFactor = 1.0,
  });

  static const double _basePin = 40.0;
  static const double _baseLabelW = 66.0;

  static _LayoutExtent layoutExtent({
    required bool showLabel,
    required String name,
    required bool showBadge,
    required double sizeFactor,
  }) {
    final pin = (_basePin * sizeFactor).clamp(10.0, _basePin);
    final labelW = (_baseLabelW * sizeFactor).clamp(36.0, _baseLabelW);
    final gap = 4 * sizeFactor;
    final rowW = showLabel && name.isNotEmpty ? pin + gap + labelW : pin;
    final badgeVisible = showBadge && sizeFactor >= 0.72;
    // Отступ под бейдж + вертикальные отступы контейнера + строка текста (~9–11 sp).
    final badgeH = badgeVisible ? (2 * sizeFactor + 4 * sizeFactor + 12 * sizeFactor) : 0.0;
    final h = pin + badgeH;
    final w = badgeVisible ? math.max(rowW, 104 * sizeFactor) : rowW;
    return _LayoutExtent(w, h);
  }

  @override
  Widget build(BuildContext context) {
    final showBadge = totalSelectedPriceKopecks != null && totalSelectedPriceKopecks! > 0;
    final pin = (_basePin * sizeFactor).clamp(10.0, _basePin);
    final labelW = (_baseLabelW * sizeFactor).clamp(36.0, _baseLabelW);
    final gap = 4 * sizeFactor;
    final borderW = math.max(1.0, 2 * sizeFactor);
    final innerPad = math.max(1.0, 2 * sizeFactor);
    final iconSize = (20 * sizeFactor).clamp(10.0, 20.0);
    final labelFont = (11 * sizeFactor).clamp(7.0, 11.0);
    final loadImage = sizeFactor >= 0.5 && imageUrl != null && imageUrl!.isNotEmpty;
    final badgeVisible = showBadge && sizeFactor >= 0.72;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(
          width: showLabel && name.isNotEmpty ? pin + gap + labelW : pin,
          height: pin,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              isFavorite
                  ? _FavoritePartnerHeartPin(
                      imageUrl: imageUrl,
                      loadImage: loadImage,
                      pin: pin,
                      borderW: borderW,
                      iconSize: iconSize,
                      sizeFactor: sizeFactor,
                    )
                  : Container(
                      width: pin,
                      height: pin,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: context.palette.success, width: borderW),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4 * sizeFactor,
                            offset: Offset(0, sizeFactor),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(innerPad),
                      child: ClipOval(
                        child: loadImage
                            ? CachedNetworkImage(
                                imageUrl: imageUrl!,
                                fit: BoxFit.cover,
                                width: pin - 2 * innerPad,
                                height: pin - 2 * innerPad,
                                placeholder: (context, url) => Center(
                                  child: SizedBox(
                                    width: 18 * sizeFactor,
                                    height: 18 * sizeFactor,
                                    child: const CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                                errorWidget: (ctx, error, stackTrace) => _iconContent(ctx, iconSize),
                              )
                            : _iconContent(context, iconSize),
                      ),
                    ),
              if (showLabel && name.isNotEmpty) ...[
                SizedBox(width: gap),
                SizedBox(
                  width: labelW,
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: labelFont, color: Colors.black, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (badgeVisible) ...[
          SizedBox(height: 2 * sizeFactor),
          Container(
            constraints: BoxConstraints(maxWidth: 112 * sizeFactor),
            padding: EdgeInsets.symmetric(horizontal: 5 * sizeFactor, vertical: 3 * sizeFactor),
            decoration: BoxDecoration(
              color: const Color(0xFFE65100),
              borderRadius: BorderRadius.circular(10 * sizeFactor),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 2, offset: Offset(0, sizeFactor)),
              ],
            ),
            child: _PartnerSlotBadgeRow(
              sizeFactor: sizeFactor,
              priceKopecks: totalSelectedPriceKopecks!,
              durationMinutes: totalSelectedDurationMinutes ?? 0,
              nearestSlotIsoUtc: nearestSlotIsoUtc,
            ),
          ),
        ],
      ],
    );
  }

  Widget _iconContent(BuildContext context, double iconSize) {
    final p = context.palette;
    return Container(
      color: p.surface,
      child: Center(
        child: Icon(Icons.key_rounded, size: iconSize, color: p.success),
      ),
    );
  }
}

/// Пин избранного: фото/логотип в силуэте насыщенного красного сердца, лёгкая тень и светлая кайма.
class _FavoritePartnerHeartPin extends StatelessWidget {
  const _FavoritePartnerHeartPin({
    required this.loadImage,
    required this.pin,
    required this.borderW,
    required this.iconSize,
    required this.sizeFactor,
    this.imageUrl,
  });

  final String? imageUrl;
  final bool loadImage;
  final double pin;
  final double borderW;
  final double iconSize;
  final double sizeFactor;

  @override
  Widget build(BuildContext _) {
    return SizedBox(
      width: pin,
      height: pin,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(pin, pin),
            painter: const _MapHeartDropShadowPainter(),
          ),
          Positioned.fill(
            child: ClipPath(
              clipper: _MapHeartShapeClipper(),
              child: loadImage
                  ? CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      width: pin,
                      height: pin,
                      placeholder: (context, url) => Container(
                        color: const Color(0xFFEF9A9A),
                        child: Center(
                          child: SizedBox(
                            width: 18 * sizeFactor,
                            height: 18 * sizeFactor,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (ctx, error, stackTrace) => _heartFallbackFill(),
                    )
                  : _heartFallbackFill(),
            ),
          ),
          CustomPaint(
            size: Size(pin, pin),
            painter: _MapHeartEdgePainter(
              borderW: math.max(1.0, borderW * 0.85),
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heartFallbackFill() {
    return Container(
      width: pin,
      height: pin,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFF8A80),
            Color(0xFFE53935),
            Color(0xFFC62828),
            Color(0xFFB71C1C),
          ],
          stops: [0.0, 0.35, 0.7, 1.0],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.key_rounded,
          size: iconSize,
          color: Colors.white,
        ),
      ),
    );
  }
}
