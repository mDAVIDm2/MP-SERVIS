import 'package:dio/dio.dart';
import 'api_endpoints.dart';
import 'api_exceptions.dart';

Uri _resolveBytesUri(String pathOrUrl) {
  final p = pathOrUrl.trim();
  if (p.startsWith('http://') || p.startsWith('https://')) {
    return Uri.parse(p);
  }
  var base = ApiEndpoints.baseUrl.trim();
  if (base.endsWith('/')) base = base.substring(0, base.length - 1);
  var rel = p.startsWith('/') ? p.substring(1) : p;
  if (rel.startsWith('api/v1/')) {
    rel = rel.substring('api/v1/'.length);
  }
  return Uri.parse('$base/$rel');
}

/// Максимальное число повторных попыток при сетевой ошибке или таймауте.
const int _kMaxRetries = 2;
const Duration _kRetryDelay = Duration(milliseconds: 500);

bool _isRetryableTransportError(DioException err) {
  if (err.type == DioExceptionType.connectionTimeout ||
      err.type == DioExceptionType.sendTimeout ||
      err.type == DioExceptionType.receiveTimeout ||
      err.type == DioExceptionType.connectionError) {
    return true;
  }
  if (err.type == DioExceptionType.unknown) {
    final buf = StringBuffer()
      ..write(err.message ?? '')
      ..write(' ')
      ..write(err.error ?? '');
    final nested = err.error;
    if (nested is ApiException) {
      buf.write(' ${nested.message}');
    }
    final combined = buf.toString().toLowerCase();
    return combined.contains('connection closed before full header') ||
        combined.contains('connection reset by peer') ||
        combined.contains('broken pipe');
  }
  return false;
}

class ApiClient {
  late final Dio _dio;
  String? _accessToken;

  /// Callback для обновления токена при 401 (из провайдера авторизации).
  Future<String?> Function()? refreshTokenCallback;

  /// Вызывается при 403 с кодом subscription_deactivated — приложение должно показать блокировку и выйти.
  void Function()? onSubscriptionDeactivated;

  /// После неудачного refresh при 401 — сброс сессии.
  void Function()? onUnauthorized;

  ApiClient()
      : refreshTokenCallback = null,
        onSubscriptionDeactivated = null,
        onUnauthorized = null {
    _dio = Dio(BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      persistentConnection: false,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Connection': 'close',
      },
    ));
    _dio.interceptors.addAll([
      _AuthInterceptor(this),
      _RetryInterceptor(_dio),
      _Refresh401Interceptor(this, _dio),
      _BusinessErrorInterceptor(this),
    ]);
  }

  void setToken(String? token) => _accessToken = token;
  String? get accessToken => _accessToken;

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken}) =>
      _dio.get<T>(path, queryParameters: queryParameters, options: options, cancelToken: cancelToken);
  Future<Response<T>> post<T>(String path, {dynamic data, Options? options, CancelToken? cancelToken}) =>
      _dio.post<T>(path, data: data, options: options, cancelToken: cancelToken);
  Future<Response<T>> put<T>(String path, {dynamic data, Options? options, CancelToken? cancelToken}) =>
      _dio.put<T>(path, data: data, options: options, cancelToken: cancelToken);
  Future<Response<T>> patch<T>(String path, {dynamic data, Options? options, CancelToken? cancelToken}) =>
      _dio.patch<T>(path, data: data, options: options, cancelToken: cancelToken);
  Future<Response<T>> delete<T>(String path, {dynamic data, Options? options, CancelToken? cancelToken}) =>
      _dio.delete<T>(path, data: data, options: options, cancelToken: cancelToken);

  Future<Response<T>> upload<T>(
    String path, {
    required FormData formData,
    void Function(int, int)? onSendProgress,
  }) =>
      _dio.post<T>(path, data: formData, onSendProgress: onSendProgress);

  /// GET с ответом в виде байтов (корректная склейка URL для путей с ведущим `/`).
  Future<Result<List<int>>> getBytes(String path, {CancelToken? cancelToken}) async {
    try {
      final uri = _resolveBytesUri(path);
      final res = await _dio.getUri<List<int>>(
        uri,
        options: Options(responseType: ResponseType.bytes),
        cancelToken: cancelToken,
      );
      final data = res.data;
      if (data == null) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ'));
      }
      return Result.success(data);
    } on DioException catch (e) {
      final apiErr = e.error is ApiException ? e.error as ApiException : ApiException.fromDioError(e);
      assert(() {
        // ignore: avoid_print
        print('ApiClient.getBytes failed: $path — ${apiErr.message}');
        return true;
      }());
      return Result.failure(apiErr);
    }
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._client);
  final ApiClient _client;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['X-MP-Servis-App'] = 'business';
    final token = _client.accessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
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

class _BusinessErrorInterceptor extends Interceptor {
  _BusinessErrorInterceptor(this._client);
  final ApiClient _client;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final apiErr = err.error is ApiException ? err.error as ApiException : ApiException.fromDioError(err);
    if (err.response?.statusCode == 401) {
      _client.onUnauthorized?.call();
    }
    if (apiErr.code == ApiErrorCode.subscriptionDeactivated) {
      _client.onSubscriptionDeactivated?.call();
    }
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: apiErr,
        type: err.type,
        response: err.response,
      ),
    );
  }
}

/// Повтор запроса при таймауте или сетевой ошибке (до _kMaxRetries раз).
class _RetryInterceptor extends Interceptor {
  _RetryInterceptor(this._dio);
  final Dio _dio;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final isRetryable = _isRetryableTransportError(err);
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
