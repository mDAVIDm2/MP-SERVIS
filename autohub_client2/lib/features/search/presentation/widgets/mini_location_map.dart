import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/map/in_app_map_tiles.dart';
import '../../../../core/theme/client_palette.dart';

/// Небольшая статичная карта (без жестов) с одной меткой — точка на OSM.
class MiniLocationMap extends StatelessWidget {
  const MiniLocationMap({
    super.key,
    required this.lat,
    required this.lng,
    this.height = 140,
    this.borderRadius = 12,
  });

  final double lat;
  final double lng;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final center = LatLng(lat, lng);
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 16,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            TileLayer(
              urlTemplate: InAppMapTiles.voyagerTemplate,
              subdomains: InAppMapTiles.voyagerSubdomains,
              userAgentPackageName: 'ru.mpservis.client',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: center,
                  width: 40,
                  height: 40,
                  alignment: Alignment.bottomCenter,
                  child: Icon(
                    Icons.location_on_rounded,
                    size: 36,
                    color: context.palette.primary,
                    shadows: const [
                      Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
                    ],
                  ),
                ),
              ],
            ),
            RichAttributionWidget(
              animationConfig: const ScaleRAWA(),
              showFlutterMapAttribution: false,
              attributions: InAppMapTiles.attributions(),
            ),
          ],
        ),
      ),
    );
  }
}
