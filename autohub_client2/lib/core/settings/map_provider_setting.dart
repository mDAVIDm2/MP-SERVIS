import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_provider.dart';

/// Подложка поиска и кнопка «открыть во внешних картах».
/// Встроенная карта — [flutter_map] + данные OSM (стиль Carto Voyager); тайлы Google/Яндекс без SDK недоступны.
enum MapProvider {
  osm('OSM', 'Только приложение: карта и точки здесь'),
  google('Google', 'Точки в приложении; кнопка открыть вид в Google Картах'),
  yandex('Яндекс', 'Точки в приложении; кнопка открыть вид в Яндекс.Картах');

  final String shortName;
  final String description;
  const MapProvider(this.shortName, this.description);
}

const _kMapProvider = 'map_provider';

final mapProviderSettingProvider = StateNotifierProvider<MapProviderSettingNotifier, MapProvider>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  return MapProviderSettingNotifier(prefs);
});

class MapProviderSettingNotifier extends StateNotifier<MapProvider> {
  MapProviderSettingNotifier(this._prefs) : super(_prefs != null ? _read(_prefs!) : MapProvider.osm);
  final SharedPreferences? _prefs;

  static MapProvider _read(SharedPreferences prefs) {
    final v = prefs.getString(_kMapProvider);
    if (v == 'google') return MapProvider.google;
    if (v == 'yandex') return MapProvider.yandex;
    return MapProvider.osm;
  }

  Future<void> set(MapProvider value) async {
    state = value;
    await _prefs?.setString(_kMapProvider, value.name);
  }
}
