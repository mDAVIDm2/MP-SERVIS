import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_provider.dart' show authProvider, sharedPreferencesProvider;

const _kKmBeforePrefix = 'maintenance_alert_km_before_';

/// За сколько километров до плановой замены показывать рекомендацию после обновления пробега (по умолчанию 500).
final maintenanceAlertKmBeforeProvider =
    StateNotifierProvider<MaintenanceAlertKmBeforeNotifier, int>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  final userId = ref.watch(authProvider).user?.id;
  return MaintenanceAlertKmBeforeNotifier(prefs, userId);
});

class MaintenanceAlertKmBeforeNotifier extends StateNotifier<int> {
  MaintenanceAlertKmBeforeNotifier(this._prefs, this._userId) : super(_load(_prefs, _userId));

  final SharedPreferences? _prefs;
  final String? _userId;

  static int _load(SharedPreferences? prefs, String? userId) {
    if (prefs == null || userId == null || userId.isEmpty) return 500;
    return prefs.getInt(_kKmBeforePrefix + userId) ?? 500;
  }

  Future<void> setKmBefore(int km) async {
    final v = km.clamp(100, 10000);
    state = v;
    if (_prefs != null && _userId != null && _userId!.isNotEmpty) {
      await _prefs!.setInt(_kKmBeforePrefix + _userId!, v);
    }
  }
}
