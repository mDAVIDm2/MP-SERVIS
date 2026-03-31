import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_colors.dart';

/// Экран выбора точки на карте (профиль организации — координаты на карте у клиентов).
/// По нажатию на карту выбирается точка, по кнопке «Готово» возвращается [LatLng].
/// По кнопке «Очистить» возвращается null (убрать точку).
class MapPickerScreen extends StatefulWidget {
  /// Начальная позиция карты / текущая точка.
  final double? initialLat;
  final double? initialLng;

  const MapPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _mapController = MapController();
  LatLng? _selected;
  static const LatLng _defaultCenter = LatLng(55.7558, 37.6173); // Москва

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _selected = LatLng(widget.initialLat!, widget.initialLng!);
    }
  }

  LatLng get _center {
    if (_selected != null) return _selected!;
    if (widget.initialLat != null && widget.initialLng != null) {
      return LatLng(widget.initialLat!, widget.initialLng!);
    }
    return _defaultCenter;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Точка на карте'),
        actions: [
          if (_selected != null)
            TextButton(
              onPressed: () {
                setState(() => _selected = null);
              },
              child: const Text('Очистить'),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(_selected);
            },
            child: const Text('Готово'),
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _center,
          initialZoom: _selected != null ? 16.0 : 12.0,
          onTap: (_, point) {
            setState(() => _selected = point);
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.autohub.business',
          ),
          if (_selected != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _selected!,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_on,
                    color: AppColors.primary,
                    size: 40,
                  ),
                ),
              ],
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _selected != null
                ? 'Широта: ${_selected!.latitude.toStringAsFixed(5)}, Долгота: ${_selected!.longitude.toStringAsFixed(5)}. Нажмите на карту, чтобы изменить.'
                : 'Нажмите на карту, чтобы указать точку на карте для клиентов.',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
