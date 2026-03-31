import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_provider.dart' show authProvider, sharedPreferencesProvider;

const _kWarnKm = 'maintenance_warn_within_km_';
const _kWarnDays = 'maintenance_warn_within_days_';

/// За сколько км до плановой замены показывать рекомендацию после обновления пробега (по умолчанию 500).
final maintenanceWarnWithinKmProvider =
    StateNotifierProvider<MaintenanceWarnKmNotifier, int>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  final userId = ref.watch(authProvider).user?.id;
  return MaintenanceWarnKmNotifier(prefs, userId);
});

class MaintenanceWarnKmNotifier extends StateNotifier<int> {
  MaintenanceWarnKmNotifier(this._prefs, this._userId) : super(_load(_prefs, _userId));

  final SharedPreferences? _prefs;
  final String? _userId;

  static int _load(SharedPreferences? prefs, String? userId) {
    if (prefs == null || userId == null) return 500;
    return prefs.getInt(_kWarnKm + userId) ?? 500;
  }

  Future<void> setKm(int km) async {
    final v = km.clamp(100, 10000);
    state = v;
    final p = _prefs;
    final u = _userId;
    if (p != null && u != null) {
      await p.setInt(_kWarnKm + u, v);
    }
  }
}

/// За сколько дней до срока по календарю показывать рекомендацию (по умолчанию 14).
final maintenanceWarnWithinDaysProvider =
    StateNotifierProvider<MaintenanceWarnDaysNotifier, int>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  final userId = ref.watch(authProvider).user?.id;
  return MaintenanceWarnDaysNotifier(prefs, userId);
});

class MaintenanceWarnDaysNotifier extends StateNotifier<int> {
  MaintenanceWarnDaysNotifier(this._prefs, this._userId) : super(_load(_prefs, _userId));

  final SharedPreferences? _prefs;
  final String? _userId;

  static int _load(SharedPreferences? prefs, String? userId) {
    if (prefs == null || userId == null) return 14;
    return prefs.getInt(_kWarnDays + userId) ?? 14;
  }

  Future<void> setDays(int days) async {
    final v = days.clamp(1, 90);
    state = v;
    final p = _prefs;
    final u = _userId;
    if (p != null && u != null) {
      await p.setInt(_kWarnDays + u, v);
    }
  }
}
