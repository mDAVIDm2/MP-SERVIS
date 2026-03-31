import 'package:dio/dio.dart';
import '../api_client.dart';
import '../api_endpoints.dart';
import '../api_exceptions.dart';
import '../../auth/auth_provider.dart';
import '../../../shared/models/user_organization_summary.dart';

/// Ответ send-code
class SendCodeResult {
  final String challengeId;
  final int expiresIn;
  final int resendAfter;

  const SendCodeResult({
    required this.challengeId,
    required this.expiresIn,
    required this.resendAfter,
  });
}

/// Результат верификации: пользователь и токены.
class VerifyResult {
  final AuthUser user;
  final String token;
  final String? refreshToken;
  final String? sessionId;

  const VerifyResult({
    required this.user,
    required this.token,
    this.refreshToken,
    this.sessionId,
  });
}

/// Реальный API авторизации и профиля.
class AuthApiService {
  AuthApiService(this._client);

  final ApiClient _client;

  Future<Result<SendCodeResult>> sendLoginCode(String email, {String channel = 'email'}) async {
    try {
      final res = await _client.post(ApiEndpoints.sendSms, data: {
        'email': email.trim().toLowerCase(),
        'channel': channel,
      });
      final data = res.data as Map<String, dynamic>?;
      if (data == null) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ'));
      }
      final cid = data['challenge_id'] as String?;
      if (cid == null || cid.isEmpty) {
        return Result.failure(const ApiException(code: ApiErrorCode.validation, message: 'Нет challenge_id в ответе'));
      }
      return Result.success(SendCodeResult(
        challengeId: cid,
        expiresIn: (data['expires_in'] as num?)?.toInt() ?? 300,
        resendAfter: (data['resend_after'] as num?)?.toInt() ?? 60,
      ));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  List<UserOrganizationSummary> _organizationsFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) {
          if (e is Map<String, dynamic>) return UserOrganizationSummary.fromJson(e);
          if (e is Map) return UserOrganizationSummary.fromJson(Map<String, dynamic>.from(e));
          return null;
        })
        .whereType<UserOrganizationSummary>()
        .where((o) => o.id.isNotEmpty)
        .toList();
  }

  Future<Result<VerifyResult>> verifyCode(
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
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ'));
      }
      final token = data['access_token'] as String? ?? data['token'] as String?;
      final userJson = data['user'] as Map<String, dynamic>? ?? data;
      if (token == null || token.isEmpty) {
        return Result.failure(const ApiException(code: ApiErrorCode.validation, message: 'Нет токена в ответе'));
      }
      final user = _userFromJson(userJson);
      return Result.success(VerifyResult(
        user: user,
        token: token,
        refreshToken: data['refresh_token'] as String?,
        sessionId: data['session_id'] as String?,
      ));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  AuthUser _userFromJson(Map<String, dynamic> j) {
    final role = BusinessRole.fromString(j['role'] as String?);
    return AuthUser(
      id: j['id'] as String? ?? '',
      phone: j['phone'] as String? ?? '',
      email: j['email'] as String?,
      name: j['name'] as String? ?? '',
      role: role,
      organizationId: j['organization_id'] as String?,
      organizations: _organizationsFromJson(j['organizations']),
    );
  }

  Future<Result<AuthUser>> getProfile() async {
    try {
      final res = await _client.get(ApiEndpoints.profile);
      final data = res.data as Map<String, dynamic>?;
      if (data == null) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ'));
      }
      return Result.success(_userFromJson(data));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<VerifyResult>> switchOrganization(String organizationId) async {
    try {
      final res = await _client.post(
        ApiEndpoints.profileSwitchOrganization,
        data: {'organization_id': organizationId},
      );
      final data = res.data as Map<String, dynamic>?;
      if (data == null) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ'));
      }
      final token = _client.accessToken;
      if (token == null || token.isEmpty) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Нет токена'));
      }
      final user = _userFromJson(data);
      return Result.success(VerifyResult(user: user, token: token));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<VerifyResult>> createOwnedOrganization({
    required String name,
    String? address,
    String? phone,
  }) async {
    try {
      final res = await _client.post(
        ApiEndpoints.profileCreateOrganization,
        data: {
          'name': name,
          if (address != null && address.trim().isNotEmpty) 'address': address.trim(),
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        },
      );
      final data = res.data as Map<String, dynamic>?;
      if (data == null) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ'));
      }
      final token = _client.accessToken;
      if (token == null || token.isEmpty) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Нет токена'));
      }
      final user = _userFromJson(data);
      return Result.success(VerifyResult(user: user, token: token));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<VerifyResult>> refresh(
    String refreshToken, {
    String? deviceId,
    String? deviceName,
    String? platform,
  }) async {
    if (refreshToken.isEmpty) {
      return Result.failure(const ApiException(code: ApiErrorCode.unauthorized, message: 'Нет refresh token'));
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
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ'));
      }
      final token = data['access_token'] as String? ?? data['token'] as String?;
      final userJson = data['user'] as Map<String, dynamic>? ?? data;
      if (token == null || token.isEmpty) {
        return Result.failure(const ApiException(code: ApiErrorCode.validation, message: 'Нет токена в ответе'));
      }
      final user = _userFromJson(userJson);
      return Result.success(VerifyResult(
        user: user,
        token: token,
        refreshToken: data['refresh_token'] as String? ?? refreshToken,
        sessionId: data['session_id'] as String?,
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
