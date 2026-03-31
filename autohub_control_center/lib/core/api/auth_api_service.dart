import 'package:dio/dio.dart';
import 'storage_provider.dart';

/// Результат запроса логина: данные при успехе, иначе код ответа (или null при сетевой ошибке).
class LoginResult {
  const LoginResult.success(this.data) : statusCode = null;
  const LoginResult.failure([this.statusCode]) : data = null;

  final Map<String, dynamic>? data;
  final int? statusCode;

  bool get isSuccess => data != null;
}

class AuthApiService {
  AuthApiService(this._dio, this._storage);

  final Dio _dio;
  // ignore: unused_field - reserved for token refresh
  final ControlCenterStorage _storage;

  /// Успех — LoginResult.success(data), иначе LoginResult.failure(statusCode). Не бросает исключений.
  Future<LoginResult> login(String email, String password) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'internal/auth/login',
        data: {'email': email.trim().toLowerCase(), 'password': password},
        options: Options(validateStatus: (status) => status != null && status! < 500),
      );
      // 200 OK или 201 Created — оба считаем успехом
      final ok = response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300 &&
          response.data != null;
      if (ok) {
        return LoginResult.success(response.data!);
      }
      return LoginResult.failure(response.statusCode);
    } on DioException catch (e) {
      return LoginResult.failure(e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>?> getMe(String token) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'internal/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException {
      return null;
    }
  }
}
