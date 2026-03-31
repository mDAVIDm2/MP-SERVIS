import 'package:dio/dio.dart';
import 'api_endpoints.dart';
import 'api_exceptions.dart';

const int _kMaxRetries = 2;
const Duration _kRetryDelay = Duration(milliseconds: 500);

/// Централизованный HTTP-клиент для работы с AutoHub API.
/// Поддерживает retry при сетевых ошибках и автоматический refresh при 401.
class ApiClient {
  late final Dio _dio;
  String? _accessToken;

  /// Callback для обновления токена при 401. Устанавливается из AuthNotifier.
  Future<String?> Function()? refreshTokenCallback;

  ApiClient() : refreshTokenCallback = null {
    _dio = Dio(BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.addAll([
      _AuthInterceptor(this),
      _RetryInterceptor(_dio),
      _Refresh401Interceptor(this, _dio),
      _ErrorInterceptor(),
    ]);
  }

  void setToken(String? token) {
    _accessToken = token;
  }

  String? get accessToken => _accessToken;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.get<T>(path, queryParameters: queryParameters, options: options, cancelToken: cancelToken);
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.post<T>(path, data: data, queryParameters: queryParameters, options: options, cancelToken: cancelToken);
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.put<T>(path, data: data, options: options, cancelToken: cancelToken);
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.patch<T>(path, data: data, options: options, cancelToken: cancelToken);
  }

  Future<Response<T>> delete<T>(
    String path, {
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.delete<T>(path, options: options, cancelToken: cancelToken);
  }

  Future<Response<T>> upload<T>(
    String path, {
    required FormData formData,
    void Function(int, int)? onSendProgress,
  }) {
    return _dio.post<T>(
      path,
      data: formData,
      onSendProgress: onSendProgress,
    );
  }

  /// Бинарный GET (фото в чате / заказе с Authorization).
  Future<Result<List<int>>> getBytes(String path, {CancelToken? cancelToken}) async {
    try {
      final res = await _dio.get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes),
        cancelToken: cancelToken,
      );
      final data = res.data;
      if (data == null) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ'));
      }
      return Result.success(data);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }
}

class _AuthInterceptor extends Interceptor {
  final ApiClient _client;
  _AuthInterceptor(this._client);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['X-AutoHub-App'] = 'client';
    final token = _client.accessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

class _RetryInterceptor extends Interceptor {
  _RetryInterceptor(this._dio);
  final Dio _dio;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final isRetryable = err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError;
    final attempt = options.extra['_retry_count'] as int? ?? 0;
    if (isRetryable && attempt < _kMaxRetries) {
      options.extra['_retry_count'] = attempt + 1;
      await Future.delayed(_kRetryDelay);
      try {
        final response = await _dio.fetch(options);
        handler.resolve(response);
        return;
      } catch (_) {}
    }
    handler.next(err);
  }
}

/// При 401 вызываем refresh и повторяем запрос (кроме /auth/refresh).
class _Refresh401Interceptor extends Interceptor {
  _Refresh401Interceptor(this._client, this._dio);
  final ApiClient _client;
  final Dio _dio;

  bool _isRefreshRequest(RequestOptions options) {
    final path = options.path;
    return path.contains('refresh') || path.contains('/auth/refresh');
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 || _isRefreshRequest(err.requestOptions)) {
      handler.next(err);
      return;
    }
    final callback = _client.refreshTokenCallback;
    if (callback == null) {
      handler.next(err);
      return;
    }
    final newToken = await callback();
    if (newToken == null || newToken.isEmpty) {
      handler.next(err);
      return;
    }
    _client.setToken(newToken);
    final opts = err.requestOptions;
    opts.headers['Authorization'] = 'Bearer $newToken';
    try {
      final response = await _dio.fetch(opts);
      handler.resolve(response);
    } catch (_) {
      handler.next(err);
    }
  }
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final apiError = err.error is ApiException ? err.error as ApiException : ApiException.fromDioError(err);
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: apiError,
        type: err.type,
        response: err.response,
      ),
    );
  }
}
