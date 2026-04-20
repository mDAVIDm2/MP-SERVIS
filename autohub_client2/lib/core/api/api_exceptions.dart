import 'package:dio/dio.dart';

import '../config/app_config.dart';

/// Коды ошибок API (из промта: ERROR HANDLING)
enum ApiErrorCode {
  validation('ERR_VALIDATION', 'Ошибка валидации'),
  unauthorized('ERR_UNAUTHORIZED', 'Не авторизован'),
  forbidden('ERR_FORBIDDEN', 'Нет прав доступа'),
  notFound('ERR_NOT_FOUND', 'Не найдено'),
  conflict('ERR_CONFLICT', 'Конфликт данных'),
  rateLimit('ERR_RATE_LIMIT', 'Слишком много запросов'),
  internal('ERR_INTERNAL', 'Внутренняя ошибка'),
  network('ERR_NETWORK', 'Нет подключения к интернету'),
  timeout('ERR_TIMEOUT', 'Сервер не отвечает'),
  unknown('ERR_UNKNOWN', 'Что-то пошло не так');

  final String code;
  final String defaultMessage;
  const ApiErrorCode(this.code, this.defaultMessage);

  static ApiErrorCode fromString(String code) {
    return ApiErrorCode.values.firstWhere(
      (e) => e.code == code,
      orElse: () => ApiErrorCode.unknown,
    );
  }
}

/// Единый класс ошибки API
class ApiException implements Exception {
  final ApiErrorCode code;
  final String message;
  final List<String>? details;
  final int? statusCode;

  const ApiException({
    required this.code,
    required this.message,
    this.details,
    this.statusCode,
  });

  /// Создать из DioException
  factory ApiException.fromDioError(DioException error) {
    final nested = error.error;
    if (nested is ApiException) {
      return nested;
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          code: ApiErrorCode.timeout,
          message: 'Сервер не отвечает. Попробуйте позже.',
        );

      case DioExceptionType.connectionError:
        return ApiException(
          code: ApiErrorCode.network,
          message:
              'Не удаётся подключиться к ${AppConfig.baseUrl}. Проверьте Nest на ПК, порт ${AppConfig.apiPort}, брандмауэр и что телефон в той же Wi‑Fi сети.',
        );

      case DioExceptionType.badResponse:
        return _fromResponse(error.response);

      case DioExceptionType.cancel:
        return const ApiException(
          code: ApiErrorCode.unknown,
          message: 'Запрос отменён',
        );

      case DioExceptionType.badCertificate:
        return ApiException(
          code: ApiErrorCode.unknown,
          message:
              'Проблема с сертификатом HTTPS (${error.message ?? 'недоверенный или просроченный'}). Для разработки используйте HTTP к API или корректный сертификат.',
        );

      case DioExceptionType.unknown:
        final res = error.response;
        if (res != null) {
          return _fromResponse(res);
        }
        final dioMsg = (error.message ?? '').trim();
        final typeName = error.type.name;
        final under = (error.error?.toString().trim() ?? '');
        final underPart = under.isNotEmpty && under != 'null' ? ' ($under)' : '';
        final api = AppConfig.baseUrl;
        if (dioMsg.isNotEmpty) {
          return ApiException(
            code: ApiErrorCode.unknown,
            message: 'Сбой запроса ($typeName): $dioMsg$underPart. API: $api',
          );
        }
        if (underPart.isNotEmpty) {
          return ApiException(
            code: ApiErrorCode.unknown,
            message:
                'Сбой сети ($typeName)$underPart. Проверьте $api, Nest на 0.0.0.0:${AppConfig.apiPort} и брандмауэр Windows.',
          );
        }
        return ApiException(
          code: ApiErrorCode.unknown,
          message:
              'Сбой запроса ($typeName). Проверьте $api, сеть и что сервер слушает 0.0.0.0:${AppConfig.apiPort}.',
        );
    }
  }

  /// Парсинг серверного ответа (формат из промта)
  static ApiException _fromResponse(Response? response) {
    if (response == null) {
      return const ApiException(
        code: ApiErrorCode.unknown,
        message: 'Пустой ответ сервера',
      );
    }

    final status = response.statusCode ?? 500;
    final data = response.data;

    // Стандартный формат: { "error": { "code": "...", "message": "...", "details": [...] } }
    if (data is Map<String, dynamic> && data.containsKey('error')) {
      final error = data['error'] as Map<String, dynamic>;
      return ApiException(
        code: ApiErrorCode.fromString(error['code'] as String? ?? ''),
        message: error['message'] as String? ?? 'Ошибка',
        details: (error['details'] as List?)?.map((e) => e.toString()).toList(),
        statusCode: status,
      );
    }

    // Fallback по HTTP коду
    switch (status) {
      case 400:
        return ApiException(code: ApiErrorCode.validation, message: 'Некорректный запрос', statusCode: status);
      case 401:
        return ApiException(code: ApiErrorCode.unauthorized, message: 'Необходима авторизация', statusCode: status);
      case 403:
        return ApiException(code: ApiErrorCode.forbidden, message: 'У вас нет доступа', statusCode: status);
      case 404:
        return ApiException(code: ApiErrorCode.notFound, message: 'Не найдено', statusCode: status);
      case 409:
        return ApiException(code: ApiErrorCode.conflict, message: 'Конфликт данных', statusCode: status);
      case 429:
        return ApiException(code: ApiErrorCode.rateLimit, message: 'Слишком много запросов', statusCode: status);
      default:
        return ApiException(code: ApiErrorCode.internal, message: 'Ошибка сервера ($status)', statusCode: status);
    }
  }

  bool get isUnauthorized => code == ApiErrorCode.unauthorized;
  bool get isNetwork => code == ApiErrorCode.network;
  bool get isTimeout => code == ApiErrorCode.timeout;

  @override
  String toString() => 'ApiException(${code.code}: $message)';
}

/// Обёртка результата: Success | Failure
/// Позволяет UI обрабатывать ошибки без try/catch
sealed class Result<T> {
  const Result();

  factory Result.success(T data) = Success<T>;
  factory Result.failure(ApiException error) = Failure<T>;

  /// Получить данные или null
  T? get dataOrNull => switch (this) {
    Success<T> s => s.data,
    Failure<T> _ => null,
  };

  /// Получить ошибку или null  
  ApiException? get errorOrNull => switch (this) {
    Success<T> _ => null,
    Failure<T> f => f.error,
  };

  /// Преобразовать результат
  R when<R>({
    required R Function(T data) success,
    required R Function(ApiException error) failure,
  }) => switch (this) {
    Success<T> s => success(s.data),
    Failure<T> f => failure(f.error),
  };
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends Result<T> {
  final ApiException error;
  const Failure(this.error);
}
