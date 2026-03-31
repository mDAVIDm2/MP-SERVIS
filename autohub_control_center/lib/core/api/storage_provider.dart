import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class ControlCenterStorage {
  Future<String?> getAccessToken();
  Future<void> setAccessToken(String token);
  Future<void> clear();
}

class SecureControlCenterStorage implements ControlCenterStorage {
  static const _keyToken = 'control_center_access_token';
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> getAccessToken() => _storage.read(key: _keyToken);

  @override
  Future<void> setAccessToken(String token) => _storage.write(key: _keyToken, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _keyToken);
}
