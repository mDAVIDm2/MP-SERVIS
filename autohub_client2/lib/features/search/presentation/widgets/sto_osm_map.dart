import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_colors.dart';
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
  /// Ограничение числа маркеров на карте, чтобы не подвисать при сотнях POI.
  static const int _maxVisibleMarkers = 120;

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
      final maxExternal = _maxVisibleMarkers - partnerEntries.length;
      final visibleExternal = maxExternal <= 0 ? <_MapEntry>[] : (externalEntries.length > maxExternal ? externalEntries.sublist(0, maxExternal) : externalEntries);
      final visiblePartners = partnerEntries;
      final withLabelIds = showLabels
          ? [...visiblePartners.take(_maxLabels), ...visibleExternal.take(_maxLabels)].take(_maxLabels).map((e) => e.id).toSet()
          : <String>{};

      final List<Marker> markers = [];
      for (final entry in visibleExternal) {
        final poi = entry.data as ExternalPOI;
        final showLabel = withLabelIds.contains(poi.id);
        markers.add(Marker(
          point: LatLng(poi.lat, poi.lng),
          width: showLabel ? 72 : 24,
          height: 24,
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () => widget.onExternalTap(poi),
            child: _RedPinWidget(showLabel: showLabel, name: poi.name, types: poi.types, fixedSize: true),
          ),
        ));
      }
      for (final entry in visiblePartners) {
          final sto = entry.data as STO;
          final showLabel = withLabelIds.contains(sto.id);
          final showBadge = sto.totalSelectedPriceKopecks != null && sto.totalSelectedPriceKopecks! > 0;
          markers.add(Marker(
            point: LatLng(sto.latitude!, sto.longitude!),
            width: showLabel ? 116 : (showBadge ? 84 : 44),
            height: showBadge ? 72 : 44,
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () => widget.onPartnerTap(sto),
              child: _PartnerMarkerWidget(
                imageUrl: (sto.logoUrl != null && sto.logoUrl!.isNotEmpty) ? sto.logoUrl : (sto.photoUrls.isNotEmpty ? sto.photoUrls.first : null),
                showLabel: showLabel,
                name: sto.name,
                totalSelectedPriceKopecks: sto.totalSelectedPriceKopecks,
                totalSelectedDurationMinutes: sto.totalSelectedDurationMinutes,
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
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.autohub.client',
          ),
          MarkerLayer(markers: _buildMarkers()),
          RichAttributionWidget(
            animationConfig: const ScaleRAWA(),
            showFlutterMapAttribution: false,
            attributions: [
              TextSourceAttribution('© OpenStreetMap'),
            ],
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

class _RedPinWidget extends StatelessWidget {
  final bool showLabel;
  final String name;
  final List<String> types;
  final bool fixedSize;

  const _RedPinWidget({required this.showLabel, required this.name, this.types = const [], this.fixedSize = true});

  static IconData _iconForTypes(List<String> types) {
    if (types.contains('Мойка')) return Icons.water_drop_rounded;
    if (types.contains('Шиномонтаж')) return Icons.tire_repair_rounded;
    return Icons.build_rounded;
  }

  static const double _pinSize = 22.0;
  static const double _labelWidth = 44.0;

  @override
  Widget build(BuildContext context) {
    final icon = _iconForTypes(types);
    return SizedBox(
      width: showLabel ? (_pinSize + 2 + _labelWidth) : _pinSize,
      height: _pinSize,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _pinSize,
            height: _pinSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.error,
              border: Border.all(color: Colors.white, width: 1),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 2, offset: const Offset(0, 1)),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 12),
          ),
          if (showLabel && name.isNotEmpty) ...[
            const SizedBox(width: 2),
            SizedBox(
              width: _labelWidth,
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 8, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PartnerMarkerWidget extends StatelessWidget {
  final String? imageUrl;
  final bool showLabel;
  final String name;
  final int? totalSelectedPriceKopecks;
  final int? totalSelectedDurationMinutes;

  const _PartnerMarkerWidget({
    this.imageUrl,
    required this.showLabel,
    required this.name,
    this.totalSelectedPriceKopecks,
    this.totalSelectedDurationMinutes,
  });

  static String _money(int kopecks) {
    if (kopecks >= 100) return '${(kopecks / 100).toStringAsFixed(0)} ₽';
    return '$kopecks ₽';
  }

  static String _duration(int minutes) => Formatters.durationMinutes(minutes);

  static const double _pinSize = 40.0;

  @override
  Widget build(BuildContext context) {
    final showBadge = totalSelectedPriceKopecks != null && totalSelectedPriceKopecks! > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(
          width: showLabel ? 110 : _pinSize,
          height: _pinSize,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _pinSize,
                height: _pinSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.success, width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 1)),
                  ],
                ),
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: imageUrl != null && imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl!,
                          fit: BoxFit.cover,
                          width: _pinSize - 4,
                          height: _pinSize - 4,
                          placeholder: (context, url) => const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                          errorWidget: (context, error, stackTrace) => _iconContent(),
                        )
                      : _iconContent(),
                ),
              ),
              if (showLabel && name.isNotEmpty) ...[
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (showBadge) ...[
          const SizedBox(height: 2),
          Container(
            constraints: const BoxConstraints(maxWidth: 80),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE65100),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 2, offset: const Offset(0, 1)),
              ],
            ),
            child: Wrap(
              spacing: 2,
              runSpacing: 0,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(_money(totalSelectedPriceKopecks!), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white)),
                const Text('·', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white)),
                Text(_duration(totalSelectedDurationMinutes ?? 0), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _iconContent() {
    return Container(
      color: AppColors.surface,
      child: const Center(
        child: Icon(Icons.key_rounded, size: 20, color: AppColors.success),
      ),
    );
  }
}
