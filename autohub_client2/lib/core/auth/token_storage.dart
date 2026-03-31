import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Хранение access/refresh/session_id в Keychain / Keystore.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _s = storage ?? const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

  final FlutterSecureStorage _s;

  static const _kAccess = 'autohub_access_token';
  static const _kRefresh = 'autohub_refresh_token';
  static const _kSession = 'autohub_session_id';

  Future<void> writeAll({
    required String accessToken,
    required String refreshToken,
    required String sessionId,
  }) async {
    await Future.wait([
      _s.write(key: _kAccess, value: accessToken),
      _s.write(key: _kRefresh, value: refreshToken),
      _s.write(key: _kSession, value: sessionId),
    ]);
  }

  Future<({String? access, String? refresh, String? sessionId})> readAll() async {
    final access = await _s.read(key: _kAccess);
    final refresh = await _s.read(key: _kRefresh);
    final sessionId = await _s.read(key: _kSession);
    return (access: access, refresh: refresh, sessionId: sessionId);
  }

  Future<void> clear() async {
    await Future.wait([
      _s.delete(key: _kAccess),
      _s.delete(key: _kRefresh),
      _s.delete(key: _kSession),
    ]);
  }
}
