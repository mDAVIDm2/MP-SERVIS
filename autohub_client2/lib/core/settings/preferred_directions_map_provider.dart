import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_provider.dart';

const _kPreferredDirectionsMap = 'preferred_directions_map';

/// Сохранённое приложение для прокладывания маршрута (mapType.name из map_launcher).
final preferredDirectionsMapProvider = StateNotifierProvider<PreferredDirectionsMapNotifier, String?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  return PreferredDirectionsMapNotifier(prefs);
});

class PreferredDirectionsMapNotifier extends StateNotifier<String?> {
  PreferredDirectionsMapNotifier(this._prefs) : super(_prefs?.getString(_kPreferredDirectionsMap));

  final SharedPreferences? _prefs;

  Future<void> set(String? mapTypeName) async {
    state = mapTypeName;
    if (mapTypeName != null) {
      await _prefs?.setString(_kPreferredDirectionsMap, mapTypeName);
    } else {
      await _prefs?.remove(_kPreferredDirectionsMap);
    }
  }
}

/// Русское название приложения карт для диалога выбора.
String directionsMapDisplayName(AvailableMap map) {
  switch (map.mapType) {
    case MapType.google:
    case MapType.googleGo:
      return 'Google карты';
    case MapType.yandexNavi:
      return 'Яндекс Навигатор';
    case MapType.yandexMaps:
      return 'Яндекс Карты';
    default:
      if (map.mapName.toLowerCase().contains('google')) return 'Google карты';
      if (map.mapName.toLowerCase().contains('yandex navigator') || map.mapName.toLowerCase().contains('яндекс навигатор')) return 'Яндекс Навигатор';
      if (map.mapName.toLowerCase().contains('yandex')) return 'Яндекс Карты';
      return map.mapName;
  }
}

/// Название по сохранённому mapType.name (для экрана «Карты» в профиле).
String preferredDirectionsMapDisplayName(String? mapTypeName) {
  if (mapTypeName == null || mapTypeName.isEmpty) return 'Не выбрано';
  switch (mapTypeName) {
    case 'google':
    case 'googleGo':
      return 'Google карты';
    case 'yandexNavi':
      return 'Яндекс Навигатор';
    case 'yandexMaps':
      return 'Яндекс Карты';
    default:
      return mapTypeName;
  }
}
