import 'package:dio/dio.dart';
import 'api_client.dart';
import 'api_endpoints.dart';
import 'api_exceptions.dart';

bool _parseAccountExistsFlag(dynamic v) {
  if (v == true || v == 1) return true;
  if (v is String) {
    final s = v.toLowerCase().trim();
    return s == 'true' || s == '1' || s == 'yes';
  }
  return false;
}

/// Ответ send-code
class SendCodeResult {
  final String challengeId;
  final int expiresIn;
  final int resendAfter;

  /// С сервера: аккаунт с этим email уже есть — достаточно кода (без имени/телефона на этом шаге).
  final bool accountExists;

  /// Только при OTP_DEBUG_RETURN_CODE на сервере (локальная отладка).
  final String? debugOtp;

  const SendCodeResult({
    required this.challengeId,
    required this.expiresIn,
    required this.resendAfter,
    this.accountExists = false,
    this.debugOtp,
  });
}

/// Результат верификации / refresh с бэкенда
class VerifyResponse {
  final String accessToken;
  final String? refreshToken;
  final String? sessionId;
  final int? expiresIn;
  final String userId;
  final String? phone;
  final String? email;
  final String name;

  const VerifyResponse({
    required this.accessToken,
    this.refreshToken,
    this.sessionId,
    this.expiresIn,
    required this.userId,
    this.phone,
    this.email,
    required this.name,
  });
}

/// Вызовы API авторизации (общий бэкенд с Business).
class AuthApiService {
  AuthApiService(this._client);
  final ApiClient _client;

  /// Вход по email OTP. Канал доставки задаётся на сервере (AUTH_OTP_DELIVERY).
  Future<Result<SendCodeResult>> sendLoginCode(String email, {String channel = 'email'}) async {
    try {
      final res = await _client.post(ApiEndpoints.sendSms, data: {
        'email': email.trim().toLowerCase(),
        'channel': channel,
      });
      final data = res.data as Map<String, dynamic>?;
      if (data == null) {
        return Result.failure(const ApiException(
          code: ApiErrorCode.internal,
          message: 'Пустой ответ сервера',
        ));
      }
      final cid = data['challenge_id'] as String?;
      if (cid == null || cid.isEmpty) {
        return Result.failure(const ApiException(
          code: ApiErrorCode.validation,
          message: 'Нет challenge_id в ответе',
        ));
      }
      final accountExists =
          _parseAccountExistsFlag(data['account_exists'] ?? data['accountExists']);
      final debugRaw = data['debug_otp'];
      final debugOtp = debugRaw is String && debugRaw.trim().isNotEmpty ? debugRaw.trim() : null;
      return Result.success(SendCodeResult(
        challengeId: cid,
        expiresIn: (data['expires_in'] as num?)?.toInt() ?? 300,
        resendAfter: (data['resend_after'] as num?)?.toInt() ?? 60,
        accountExists: accountExists,
        debugOtp: debugOtp,
      ));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<VerifyResponse>> verifyCode(
    String email,
    String challengeId,
    String code, {
    String? deviceId,
    String? deviceName,
    String? platform,
    String? phoneUnverified,
    String? name,
  }) async {
    try {
      final res = await _client.post(ApiEndpoints.verifySms, data: {
        'email': email.trim().toLowerCase(),
        'challenge_id': challengeId,
        'code': code,
        if (deviceId != null) 'device_id': deviceId,
        if (deviceName != null) 'device_name': deviceName,
        if (platform != null) 'platform': platform,
        if (phoneUnverified != null && phoneUnverified.trim().isNotEmpty) 'phone_unverified': phoneUnverified.trim(),
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      });
      final data = res.data as Map<String, dynamic>?;
      if (data == null) {
        return Result.failure(const ApiException(
          code: ApiErrorCode.internal,
          message: 'Пустой ответ сервера',
        ));
      }
      final token = data['access_token'] as String? ?? data['token'] as String?;
      final user = data['user'] as Map<String, dynamic>? ?? data;
      if (token == null || token.isEmpty) {
        return Result.failure(const ApiException(
          code: ApiErrorCode.validation,
          message: 'Нет токена в ответе',
        ));
      }
      final userId = user['id']?.toString() ?? '';
      final userPhone = user['phone'] as String?;
      final userEmail = user['email'] as String?;
      final userName = user['name']?.toString() ?? '';
      return Result.success(VerifyResponse(
        accessToken: token,
        refreshToken: data['refresh_token'] as String?,
        sessionId: data['session_id'] as String?,
        expiresIn: (data['expires_in'] as num?)?.toInt(),
        userId: userId,
        phone: userPhone,
        email: userEmail ?? email.trim().toLowerCase(),
        name: userName,
      ));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<VerifyResponse>> refresh(
    String refreshToken, {
    String? deviceId,
    String? deviceName,
    String? platform,
  }) async {
    if (refreshToken.isEmpty) {
      return Result.failure(const ApiException(
        code: ApiErrorCode.unauthorized,
        message: 'Нет refresh token',
      ));
    }
    try {
      final res = await _client.post(ApiEndpoints.refreshToken, data: {
        'refresh_token': refreshToken,
        if (deviceId != null) 'device_id': deviceId,
        if (deviceName != null) 'device_name': deviceName,
        if (platform != null) 'platform': platform,
      });
      final data = res.data as Map<String, dynamic>?;
      if (data == null) {
        return Result.failure(const ApiException(
          code: ApiErrorCode.internal,
          message: 'Пустой ответ сервера',
        ));
      }
      final token = data['access_token'] as String? ?? data['token'] as String?;
      final user = data['user'] as Map<String, dynamic>? ?? data;
      if (token == null || token.isEmpty) {
        return Result.failure(const ApiException(
          code: ApiErrorCode.validation,
          message: 'Нет токена в ответе',
        ));
      }
      final userId = user['id']?.toString() ?? '';
      final userPhone = user['phone'] as String?;
      final userEmail = user['email'] as String?;
      final userName = user['name']?.toString() ?? '';
      return Result.success(VerifyResponse(
        accessToken: token,
        refreshToken: data['refresh_token'] as String? ?? refreshToken,
        sessionId: data['session_id'] as String?,
        expiresIn: (data['expires_in'] as num?)?.toInt(),
        userId: userId,
        phone: userPhone,
        email: userEmail,
        name: userName,
      ));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<void>> logout(String refreshToken) async {
    try {
      await _client.post(ApiEndpoints.logout, data: {'refresh_token': refreshToken});
      return Result.success(null);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }
}
