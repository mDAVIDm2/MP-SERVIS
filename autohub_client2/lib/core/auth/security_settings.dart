import 'package:shared_preferences/shared_preferences.dart';

const _kPinEnabled = 'security_pin_enabled';
const _kBiometricEnabled = 'security_biometric_enabled';
const _kLockDelaySec = 'security_lock_delay_sec';
const _kLockRequestMode = 'security_lock_request_mode';

enum LockRequestMode {
  appOpen,
  authorization,
}

class SecuritySettings {
  SecuritySettings(this._prefs);

  final SharedPreferences _prefs;

  bool get pinEnabled => _prefs.getBool(_kPinEnabled) ?? false;
  bool get biometricEnabled => _prefs.getBool(_kBiometricEnabled) ?? false;
  /// 0 = блокировать сразу при уходе в фон.
  int get lockDelaySec => _prefs.getInt(_kLockDelaySec) ?? 0;
  LockRequestMode get lockRequestMode {
    final raw = _prefs.getString(_kLockRequestMode) ?? '';
    return raw == LockRequestMode.authorization.name
        ? LockRequestMode.authorization
        : LockRequestMode.appOpen;
  }

  Future<void> setPinEnabled(bool v) => _prefs.setBool(_kPinEnabled, v);
  Future<void> setBiometricEnabled(bool v) => _prefs.setBool(_kBiometricEnabled, v);
  Future<void> setLockDelaySec(int v) => _prefs.setInt(_kLockDelaySec, v);
  Future<void> setLockRequestMode(LockRequestMode mode) =>
      _prefs.setString(_kLockRequestMode, mode.name);
}
