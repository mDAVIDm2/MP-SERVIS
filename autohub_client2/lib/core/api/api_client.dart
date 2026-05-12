import 'package:dio/dio.dart';
import 'api_endpoints.dart';
import 'api_exceptions.dart';

const int _kMaxRetries = 2;
const Duration _kRetryDelay = Duration(milliseconds: 500);

/// Обрыв до HTTP-заголовков (часто мёртвый keep-alive у Dart HttpClient ↔ Node на LAN).
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

/// Централизованный HTTP-клиент для работы с API MP-Servis.
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
      // Новое TCP на каждый запрос: меньше «Connection closed before full header» при reuse сокета.
      persistentConnection: false,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Connection': 'close',
      },
    ));

    // Retry до Error — иначе в Retry попадает уже ApiException, а не сырая HttpException.
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
      options: Options(
        sendTimeout: const Duration(minutes: 3),
        receiveTimeout: const Duration(minutes: 2),
      ),
    );
  }

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

  /// Бинарный GET (фото в чате / заказе с Authorization).
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
      return Result.failure(ApiException.fromDioError(e));
    }
  }
}

class _AuthInterceptor extends Interceptor {
  final ApiClient _client;
  _AuthInterceptor(this._client);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['X-MP-Servis-App'] = 'client';
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
