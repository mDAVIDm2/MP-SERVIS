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

/// Шаг сетки кластеризации (в градусах): при меньшем зуме ячейка крупнее — точки сливаются.
double _externalClusterStepDegrees(double zoom) {
  const zRef = 11.0;
  const base = 0.052;
  return base / math.pow(2, (zoom - zRef).clamp(-1.0, 11.0));
}

/// Одна непартнёрская точка или кластер (несколько POI в ячейке).
class _ClusteredExternalView {
  _ClusteredExternalView._({
    required this.isCluster,
    required this.lat,
    required this.lng,
    required this.labelEntryId,
    this.singlePoi,
    required this.count,
  });

  factory _ClusteredExternalView.single(ExternalPOI p) {
    return _ClusteredExternalView._(
      isCluster: false,
      lat: p.lat,
      lng: p.lng,
      labelEntryId: p.id,
      singlePoi: p,
      count: 1,
    );
  }

  factory _ClusteredExternalView.cluster({
    required double lat,
    required double lng,
    required int count,
    required String labelEntryId,
  }) {
    return _ClusteredExternalView._(
      isCluster: true,
      lat: lat,
      lng: lng,
      labelEntryId: labelEntryId,
      singlePoi: null,
      count: count,
    );
  }

  final bool isCluster;
  final double lat;
  final double lng;
  final String labelEntryId;
  final ExternalPOI? singlePoi;
  final int count;
}

List<_ClusteredExternalView> _clusterExternalEntries(
  List<_MapEntry> entries, {
  required double zoom,
  required double centerLat,
  required double centerLng,
}) {
  if (entries.isEmpty) return [];
  final step = _externalClusterStepDegrees(zoom);
  final bins = <String, List<_MapEntry>>{};
  for (final e in entries) {
    final gx = (e.lat / step).floor();
    final gy = (e.lng / step).floor();
    final key = '$gx|$gy';
    bins.putIfAbsent(key, () => []).add(e);
  }
  final out = <_ClusteredExternalView>[];
  for (final bin in bins.entries) {
    final list = bin.value;
    if (list.length == 1) {
      out.add(_ClusteredExternalView.single(list.first.data as ExternalPOI));
    } else {
      var sl = 0.0;
      var sn = 0.0;
      for (final x in list) {
        sl += x.lat;
        sn += x.lng;
      }
      final n = list.length;
      out.add(_ClusteredExternalView.cluster(
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

/// Callback с границами видимой области: minLat, minLng, maxLat, maxLng.
typedef VisibleBoundsCallback = void Function(double minLat, double minLng, double maxLat, double maxLng);

/// Карта на OpenStreetMap (бесплатно). Те же колбэки, что и у прежней карты.
class STOOSMMap extends StatefulWidget {
  final LatLng initialCenter;
  final double initialZoom;
  final List<STO> partners;
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

class _STOOSMMapState extends State<STOOSMMap> {
  final MapController _mapController = MapController();
  double _currentZoom = 14;
  LatLng _center = const LatLng(45.0355, 38.9753);
  bool _ready = false;
  Timer? _boundsDebounce;
  static const Duration _boundsDebounceDuration = Duration(milliseconds: 900);
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
    _center = widget.initialCenter;
    _currentZoom = widget.initialZoom;
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
    _boundsDebounce?.cancel();
    super.dispose();
  }

  void _onPositionChanged(MapCamera position, bool hasGesture) {
    if (!mounted) return;
    final newCenter = position.center;
    final newZoom = position.zoom;
    setState(() {
      _center = newCenter;
      if ((newZoom - _currentZoom).abs() > 0.2) _currentZoom = newZoom;
    });
    widget.onCameraMove?.call(newZoom);
    widget.onCameraChanged?.call(newCenter, newZoom);
    _boundsDebounce?.cancel();
    _boundsDebounce = Timer(_boundsDebounceDuration, _notifyVisibleBounds);
  }

  void _notifyVisibleBounds() {
    if (!mounted) return;
    final cb = widget.onVisibleBoundsChanged;
    if (cb == null) return;
    try {
      final zoom = _currentZoom;
      final lat = _center.latitude;
      final lng = _center.longitude;
      final scale = 180 / (math.pow(2, zoom) * 256);
      final dLat = 0.5 * scale * 256;
      final dLng = scale * 256;
      final minLat = lat - dLat;
      final maxLat = lat + dLat;
      final minLng = lng - dLng;
      final maxLng = lng + dLng;
      if (mounted) cb(minLat, minLng, maxLat, maxLng);
    } catch (_) {}
  }

  /// Подпись по партнёрам: при смене выбранных услуг (цены на маркерах) кэш маркеров нужно сбросить.
  int _partnersPriceSignature() {
    return widget.partners.fold<int>(
      0,
      (s, p) => s ^ (p.id.hashCode + (p.totalSelectedPriceKopecks ?? 0)),
    );
  }

  int _cachedPriceSignature = 0;

  bool _shouldRebuildMarkers() {
    final pl = widget.partners.length;
    final el = widget.externals.length;
    final hasUser = widget.userLocation != null;
    final priceSig = _partnersPriceSignature();
    if (pl != _cachedPartnersLength || el != _cachedExternalsLength ||
        _center.latitude != _cachedCenterLat || _center.longitude != _cachedCenterLng ||
        _currentZoom != _cachedZoom || hasUser != _cachedHasUserLocation ||
        priceSig != _cachedPriceSignature) {
      _cachedPartnersLength = pl;
      _cachedExternalsLength = el;
      _cachedCenterLat = _center.latitude;
      _cachedCenterLng = _center.longitude;
      _cachedZoom = _currentZoom;
      _cachedHasUserLocation = hasUser;
      _cachedPriceSignature = priceSig;
      return true;
    }
    return false;
  }

  List<Marker> _buildMarkers() {
    if (!_shouldRebuildMarkers() && _cachedMarkers != null) return _cachedMarkers!;
    try {
      final showLabels = _currentZoom >= _labelZoomThreshold;
      final centerLat = _center.latitude;
      final centerLng = _center.longitude;

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
      var externalVisuals = _clusterExternalEntries(
        externalEntries,
        zoom: _currentZoom,
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

      final zf = _markerSizeFactor(_currentZoom);
      final List<Marker> markers = [];
      for (final v in externalVisuals) {
        if (v.isCluster) {
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
              onTap: () {
                final nextZoom = (_currentZoom + 1.35).clamp(4.0, 18.0);
                _mapController.move(LatLng(v.lat, v.lng), nextZoom);
              },
              child: _ExternalClusterBubble(
                count: v.count,
                sizeFactor: zf,
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
                totalSelectedPriceKopecks: sto.totalSelectedPriceKopecks,
                totalSelectedDurationMinutes: sto.totalSelectedDurationMinutes,
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
      _cachedCenterLat = _center.latitude;
      _cachedCenterLng = _center.longitude;
      _cachedZoom = _currentZoom;
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

/// Кластер непартнёрских точек: число в круге; тап — приблизить карту к группе.
class _ExternalClusterBubble extends StatelessWidget {
  final int count;
  final double sizeFactor;

  const _ExternalClusterBubble({
    required this.count,
    this.sizeFactor = 1.0,
  });

  static _LayoutExtent layoutExtent({required int count, required double sizeFactor}) {
    final bubble = (42 * sizeFactor).clamp(30.0, 46.0);
    return _LayoutExtent(bubble, bubble);
  }

  @override
  Widget build(BuildContext context) {
    final s = (42 * sizeFactor).clamp(30.0, 46.0);
    final font = (13 * sizeFactor).clamp(10.0, 15.0);
    final txt = count > 99 ? '99+' : '$count';
    return SizedBox(
      width: s,
      height: s,
      child: Material(
        color: const Color(0xFFE65100),
        shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 2.2)),
        elevation: 3,
        shadowColor: Colors.black45,
        child: Center(
          child: Text(
            txt,
            style: TextStyle(
              color: Colors.white,
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
            style: TextStyle(fontSize: fontSize, color: context.palette.textPrimary, fontWeight: FontWeight.w600),
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

class _PartnerMarkerWidget extends StatelessWidget {
  final String? imageUrl;
  final bool showLabel;
  final String name;
  final int? totalSelectedPriceKopecks;
  final int? totalSelectedDurationMinutes;
  final double sizeFactor;

  const _PartnerMarkerWidget({
    this.imageUrl,
    required this.showLabel,
    required this.name,
    this.totalSelectedPriceKopecks,
    this.totalSelectedDurationMinutes,
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
    final w = badgeVisible ? math.max(rowW, 80 * sizeFactor) : rowW;
    return _LayoutExtent(w, h);
  }

  static String _money(int kopecks) {
    if (kopecks >= 100) return '${(kopecks / 100).toStringAsFixed(0)} ₽';
    return '$kopecks ₽';
  }

  static String _duration(int minutes) => Formatters.durationMinutes(minutes);

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
              Container(
                width: pin,
                height: pin,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: context.palette.success, width: borderW),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4 * sizeFactor, offset: Offset(0, sizeFactor)),
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
            constraints: BoxConstraints(maxWidth: 80 * sizeFactor),
            padding: EdgeInsets.symmetric(horizontal: 4 * sizeFactor, vertical: 2 * sizeFactor),
            decoration: BoxDecoration(
              color: const Color(0xFFE65100),
              borderRadius: BorderRadius.circular(10 * sizeFactor),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 2, offset: Offset(0, sizeFactor)),
              ],
            ),
            child: Wrap(
              spacing: 2 * sizeFactor,
              runSpacing: 0,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _money(totalSelectedPriceKopecks!),
                  style: TextStyle(fontSize: (9 * sizeFactor).clamp(7.0, 9.0), fontWeight: FontWeight.w600, color: Colors.white),
                ),
                Text('·', style: TextStyle(fontSize: (9 * sizeFactor).clamp(7.0, 9.0), fontWeight: FontWeight.w600, color: Colors.white)),
                Text(
                  _duration(totalSelectedDurationMinutes ?? 0),
                  style: TextStyle(fontSize: (9 * sizeFactor).clamp(7.0, 9.0), fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ],
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
