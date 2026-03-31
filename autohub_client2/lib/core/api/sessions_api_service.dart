import 'package:dio/dio.dart';
import 'api_client.dart';
import 'api_endpoints.dart';
import 'api_exceptions.dart';

class SessionItemDto {
  final String id;
  final String? createdAt;
  final String? lastSeenAt;
  final String? deviceName;
  final String? platform;
  final bool revoked;
  final bool isCurrent;

  SessionItemDto({
    required this.id,
    this.createdAt,
    this.lastSeenAt,
    this.deviceName,
    this.platform,
    required this.revoked,
    required this.isCurrent,
  });

  factory SessionItemDto.fromJson(Map<String, dynamic> j) {
    return SessionItemDto(
      id: j['id'] as String? ?? '',
      createdAt: j['created_at'] as String?,
      lastSeenAt: j['last_seen_at'] as String?,
      deviceName: j['device_name'] as String?,
      platform: j['platform'] as String?,
      revoked: j['revoked'] == true,
      isCurrent: j['is_current'] == true,
    );
  }
}

class SessionsApiService {
  SessionsApiService(this._client);
  final ApiClient _client;

  Future<Result<List<SessionItemDto>>> listSessions() async {
    try {
      final res = await _client.get(ApiEndpoints.authSessions);
      final data = res.data as Map<String, dynamic>?;
      final items = data?['items'];
      if (items is! List) return Result.success([]);
      final out = items
          .map((e) => e is Map<String, dynamic> ? SessionItemDto.fromJson(e) : null)
          .whereType<SessionItemDto>()
          .toList();
      return Result.success(out);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<void>> revokeSession(String id) async {
    try {
      await _client.delete(ApiEndpoints.authSession(id));
      return Result.success(null);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<void>> revokeOthers() async {
    try {
      await _client.post(ApiEndpoints.authRevokeOthers);
      return Result.success(null);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }
}
