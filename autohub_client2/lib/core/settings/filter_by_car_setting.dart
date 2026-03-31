import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_provider.dart';

const _kFilterByCarPrefix = 'filter_by_car_';
const _kSelectedCarIdPrefix = 'selected_car_id_';

/// Включено ли фильтрование заказов/истории по выбранному авто. Состояние привязано к аккаунту (userId).
final filterByCarSettingProvider = StateNotifierProvider<FilterByCarSettingNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  final userId = ref.watch(authProvider).user?.id;
  return FilterByCarSettingNotifier(prefs, userId);
});

class FilterByCarSettingNotifier extends StateNotifier<bool> {
  FilterByCarSettingNotifier(this._prefs, this._userId)
      : super(_prefs != null && _userId != null
            ? (_prefs.getBool(_kFilterByCarPrefix + _userId!) ?? true)
            : true);
  final SharedPreferences? _prefs;
  final String? _userId;

  String get _key => _kFilterByCarPrefix + (_userId ?? '');

  Future<void> set(bool value) async {
    state = value;
    await _prefs?.setBool(_key, value);
  }
}

/// ID выбранного в гараже автомобиля. Привязан к аккаунту (userId).
final selectedCarIdProvider = StateNotifierProvider<SelectedCarIdNotifier, String?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  final userId = ref.watch(authProvider).user?.id;
  return SelectedCarIdNotifier(prefs, userId);
});

class SelectedCarIdNotifier extends StateNotifier<String?> {
  SelectedCarIdNotifier(this._prefs, this._userId)
      : super(_prefs != null && _userId != null
            ? _prefs.getString(_kSelectedCarIdPrefix + _userId!)
            : null);
  final SharedPreferences? _prefs;
  final String? _userId;

  String get _key => _kSelectedCarIdPrefix + (_userId ?? '');

  Future<void> set(String? carId) async {
    state = carId;
    if (carId != null) {
      await _prefs?.setString(_key, carId);
    } else {
      await _prefs?.remove(_key);
    }
  }
}
