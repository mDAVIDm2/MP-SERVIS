import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Локальный PIN (только на устройстве): соль + SHA-256 в secure storage.
class PinVault {
  PinVault({FlutterSecureStorage? storage})
      : _s = storage ?? const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

  final FlutterSecureStorage _s;
  static const _kSalt = 'autohub_pin_salt';
  static const _kHash = 'autohub_pin_hash_b64';

  Future<bool> hasPin() async {
    final h = await _s.read(key: _kHash);
    return h != null && h.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    if (pin.length < 4 || pin.length > 8) throw ArgumentError('PIN 4–8 цифр');
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final saltB64 = base64UrlEncode(salt);
    final hash = _hashPin(saltB64, pin);
    await _s.write(key: _kSalt, value: saltB64);
    await _s.write(key: _kHash, value: hash);
  }

  Future<bool> verify(String pin) async {
    final saltB64 = await _s.read(key: _kSalt);
    final expected = await _s.read(key: _kHash);
    if (saltB64 == null || expected == null) return false;
    return _hashPin(saltB64, pin) == expected;
  }

  Future<void> clear() async {
    await _s.delete(key: _kSalt);
    await _s.delete(key: _kHash);
  }

  String _hashPin(String saltB64, String pin) {
    final bytes = utf8.encode('$saltB64:$pin');
    return base64UrlEncode(sha256.convert(bytes).bytes);
  }
}
