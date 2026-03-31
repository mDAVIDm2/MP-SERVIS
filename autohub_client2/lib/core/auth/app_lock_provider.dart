import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_provider.dart';
import 'pin_vault.dart';
import 'security_settings.dart';

final securitySettingsProvider = Provider<SecuritySettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  if (prefs == null) return SecuritySettings(_EphemeralPrefs());
  return SecuritySettings(prefs);
});

final pinVaultProvider = Provider<PinVault>((ref) => PinVault());

final localAuthProvider = Provider<LocalAuthentication>((ref) => LocalAuthentication());

/// true = показать экран разблокировки поверх приложения.
class AppLockNotifier extends StateNotifier<bool> {
  AppLockNotifier(this.ref) : super(false);

  final Ref ref;

  Future<void> onLifecycleChange(AppLifecycleState state) async {
    // По продуктовой логике: при сворачивании/возврате PIN не запрашиваем.
    // Блокировка происходит только после входа/холодного старта (lockNow).
    if (state == AppLifecycleState.resumed) return;
  }

  void unlock() => state = false;

  void lockNow() => state = true;
}

final appLockProvider = StateNotifierProvider<AppLockNotifier, bool>((ref) {
  return AppLockNotifier(ref);
});

class _EphemeralPrefs implements SharedPreferences {
  final Map<String, Object> _m = {};
  @override
  Future<bool> clear() async {
    _m.clear();
    return true;
  }

  @override
  Future<bool> commit() async => true;

  @override
  bool containsKey(String key) => _m.containsKey(key);

  @override
  Object? get(String key) => _m[key];

  @override
  bool? getBool(String key) => _m[key] as bool?;

  @override
  double? getDouble(String key) => _m[key] as double?;

  @override
  int? getInt(String key) => _m[key] as int?;

  @override
  Set<String> getKeys() => _m.keys.toSet();

  @override
  String? getString(String key) => _m[key] as String?;

  @override
  List<String>? getStringList(String key) => _m[key] as List<String>?;

  @override
  Future<bool> reload() async => true;

  @override
  Future<bool> remove(String key) async {
    _m.remove(key);
    return true;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    _m[key] = value;
    return true;
  }

  @override
  Future<bool> setDouble(String key, double value) async {
    _m[key] = value;
    return true;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    _m[key] = value;
    return true;
  }

  @override
  Future<bool> setString(String key, String value) async {
    _m[key] = value;
    return true;
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    _m[key] = value;
    return true;
  }
}
