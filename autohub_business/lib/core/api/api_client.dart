import 'package:dio/dio.dart';
import 'api_endpoints.dart';
import 'api_exceptions.dart';

/// Максимальное число повторных попыток при сетевой ошибке или таймауте.
const int _kMaxRetries = 2;
const Duration _kRetryDelay = Duration(milliseconds: 500);

class ApiClient {
  late final Dio _dio;
  String? _accessToken;

  /// Вызывается при 403 с кодом subscription_deactivated — приложение должно показать блокировку и выйти.
  void Function()? onSubscriptionDeactivated;
  /// Вызывается при 401 Unauthorized — сессия истекла/некорректна.
  void Function()? onUnauthorized;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ));
    _dio.interceptors.addAll([
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['X-AutoHub-App'] = 'business';
          if (_accessToken != null) {
            options.headers['Authorization'] = 'Bearer $_accessToken';
          }
          handler.next(options);
        },
      ),
      _RetryInterceptor(_dio),
      InterceptorsWrapper(
        onError: (err, handler) {
          if (err.response?.statusCode == 401) {
            onUnauthorized?.call();
          }
          final apiErr = err.error is ApiException ? err.error as ApiException : ApiException.fromDioError(err);
          if (apiErr.code == ApiErrorCode.subscriptionDeactivated) {
            onSubscriptionDeactivated?.call();
          }
          handler.reject(
            DioException(
              requestOptions: err.requestOptions,
              error: apiErr,
              type: err.type,
              response: err.response,
            ),
          );
        },
      ),
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
  Future<Response<T>> delete<T>(String path, {Options? options, CancelToken? cancelToken}) =>
      _dio.delete<T>(path, options: options, cancelToken: cancelToken);

  Future<Response<T>> upload<T>(
    String path, {
    required FormData formData,
    void Function(int, int)? onSendProgress,
  }) =>
      _dio.post<T>(path, data: formData, onSendProgress: onSendProgress);

  /// GET с ответом в виде байтов. При ошибке возвращает Failure с ApiException (логируем причину).
  Future<Result<Response<List<int>>>> getBytes(String path, {CancelToken? cancelToken}) async {
    try {
      final res = await _dio.get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes),
        cancelToken: cancelToken,
      );
      return Result.success(res);
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

/// Повтор запроса при таймауте или сетевой ошибке (до _kMaxRetries раз).
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
