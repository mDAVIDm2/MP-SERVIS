import 'package:flutter/material.dart';
import '../../../../core/geo/reverse_geocode_service.dart';
import '../../../../core/theme/client_palette.dart';
import 'mini_location_map.dart';

/// Строка адреса и при наличии координат — мини-карта; пустой адрес с бэкенда
/// дополняется обратным геокодингом (Nominatim).
class LocationPreviewCard extends StatefulWidget {
  const LocationPreviewCard({
    super.key,
    this.latitude,
    this.longitude,
    required this.staticAddress,
    this.distanceTrailing,
    this.compact = false,
  });

  final double? latitude;
  final double? longitude;
  final String staticAddress;
  final String? distanceTrailing;
  /// Без мини-карты (например блок записи в компактной карточке).
  final bool compact;

  @override
  State<LocationPreviewCard> createState() => _LocationPreviewCardState();
}

class _LocationPreviewCardState extends State<LocationPreviewCard> {
  String? _resolved;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _maybeGeocode();
  }

  @override
  void didUpdateWidget(LocationPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.staticAddress != widget.staticAddress ||
        oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _resolved = null;
      _maybeGeocode();
    }
  }

  void _maybeGeocode() {
    final hasStatic = widget.staticAddress.trim().isNotEmpty;
    final lat = widget.latitude;
    final lng = widget.longitude;
    if (hasStatic || lat == null || lng == null) return;
    _loadGeocode(lat, lng);
  }

  Future<void> _loadGeocode(double lat, double lng) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
    });
    final text = await ReverseGeocodeService.lookup(lat, lng);
    if (!mounted) return;
    setState(() {
      _resolved = text;
      _loading = false;
    });
  }

  String get _displayLine {
    final s = widget.staticAddress.trim();
    if (s.isNotEmpty) return s;
    if (_loading) return 'Определяем адрес…';
    final r = _resolved?.trim();
    if (r != null && r.isNotEmpty) return r;
    if (widget.latitude != null && widget.longitude != null) {
      return 'Адрес по картам не найден';
    }
    return 'Адрес не указан';
  }

  @override
  Widget build(BuildContext context) {
    final lat = widget.latitude;
    final lng = widget.longitude;

    return Padding(
      padding: EdgeInsets.only(bottom: widget.compact ? 0 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on_rounded, size: 18, color: context.palette.textTertiary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  _displayLine,
                  style: TextStyle(
                    fontSize: 14,
                    color: widget.compact ? context.palette.textSecondary : context.palette.textPrimary,
                  ),
                ),
              ),
              if (widget.distanceTrailing != null)
                Text(
                  widget.distanceTrailing!,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.palette.textSecondary,
                  ),
                ),
            ],
          ),
          if (!widget.compact && lat != null && lng != null) ...[
            SizedBox(height: 8),
            MiniLocationMap(lat: lat, lng: lng),
          ],
        ],
      ),
    );
  }
}
