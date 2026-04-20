import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../settings/map_provider_setting.dart';

/// Подложка для [flutter_map]: единое место для URL тайлов и атрибуции.
///
/// Юридически нельзя подставлять тайлы Google/Яндекс без их SDK и ключей.
/// Для режимов [MapProvider.google] / [MapProvider.yandex] в приложении
/// остаётся та же векторная логика маркеров; отличается кнопка «Открыть в …».
class InAppMapTiles {
  InAppMapTiles._();

  /// Carto Voyager — современная читаемая подложка на данных OSM (бесплатно при соблюдении условий CARTO).
  static const voyagerTemplate =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';

  static const List<String> voyagerSubdomains = ['a', 'b', 'c', 'd'];

  /// Классическая OSM (резерв / при отключении Carto).
  static const osmTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static String urlTemplateFor(MapProvider provider) {
    switch (provider) {
      case MapProvider.osm:
      case MapProvider.google:
      case MapProvider.yandex:
        return voyagerTemplate;
    }
  }

  static List<String> subdomainsFor(MapProvider provider) {
    switch (provider) {
      case MapProvider.osm:
      case MapProvider.google:
      case MapProvider.yandex:
        return voyagerSubdomains;
    }
  }

  /// Минимальная атрибуция (требования лицензий OSM / CARTO).
  static List<SourceAttribution> attributions() {
    return const [
      TextSourceAttribution('© OpenStreetMap © CARTO'),
    ];
  }
}

/// Открыть текущий вид карты во внешнем приложении (Google или Яндекс).
Future<void> launchExternalMapView({
  required MapProvider provider,
  required LatLng center,
  required double zoom,
}) async {
  final lat = center.latitude;
  final lng = center.longitude;
  final z = zoom.clamp(1.0, 19.0).round();

  final uri = switch (provider) {
    MapProvider.google => Uri.parse('https://www.google.com/maps/@$lat,$lng,${z}z'),
    MapProvider.yandex => Uri.parse('https://yandex.ru/maps/?ll=$lng,$lat&z=$z'),
    MapProvider.osm => Uri.parse('https://www.openstreetmap.org/#map=$z/$lat/$lng'),
  };

  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) {
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  }
}
