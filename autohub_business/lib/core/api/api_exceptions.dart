import 'package:dio/dio.dart';

import '../config/app_config.dart';

enum ApiErrorCode {
  validation('ERR_VALIDATION', 'Ошибка валидации'),
  unauthorized('ERR_UNAUTHORIZED', 'Не авторизован'),
  forbidden('ERR_FORBIDDEN', 'Нет прав доступа'),
  subscriptionDeactivated('subscription_deactivated', 'Подписка деактивирована'),
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

  factory ApiException.fromDioError(DioException error) {
    final nested = error.error;
    if (nested is ApiException) {
      return nested;
    }

    String underlyingDetail() {
      final o = error.error;
      if (o == null) return '';
      final s = o.toString().trim();
      if (s.isEmpty || s == 'null') return '';
      return s;
    }

    final api = AppConfig.baseUrl;

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
              'Не удаётся достучаться до API ($api). Телефон и ПК в одной Wi‑Fi сети, на ПК запущен Nest и в брандмауэре разрешён входящий TCP порт ${AppConfig.apiPort}.',
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
              'Проблема с сертификатом HTTPS (${error.message ?? 'недоверенный'}). Для разработки по LAN используйте HTTP в baseUrl.',
        );
      case DioExceptionType.unknown:
        if (error.response != null) {
          return _fromResponse(error.response);
        }
        final dioMsg = (error.message ?? '').trim();
        final under = underlyingDetail();
        if (dioMsg.isNotEmpty) {
          return ApiException(
            code: ApiErrorCode.unknown,
            message: 'Сбой сети (${error.type.name}): $dioMsg${under.isNotEmpty ? ' ($under)' : ''}. API: $api',
          );
        }
        if (under.isNotEmpty) {
          return ApiException(
            code: ApiErrorCode.unknown,
            message:
                'Сбой сети (${error.type.name}): $under. Проверьте API $api, что Nest слушает 0.0.0.0:${AppConfig.apiPort} и порт открыт в брандмауэре Windows.',
          );
        }
        return ApiException(
          code: ApiErrorCode.unknown,
          message:
              'Сбой сети (${error.type.name}). Проверьте API $api, Wi‑Fi без изоляции клиентов, Nest на 0.0.0.0:${AppConfig.apiPort} и брандмауэр.',
        );
    }
  }

  static ApiException _fromResponse(Response? response) {
    if (response == null) {
      return const ApiException(code: ApiErrorCode.unknown, message: 'Пустой ответ сервера');
    }
    final status = response.statusCode ?? 500;
    dynamic data = response.data;
    if (data is String) {
      final t = data.trim();
      return ApiException(
        code: status >= 500 ? ApiErrorCode.internal : ApiErrorCode.unknown,
        message: t.isEmpty
            ? 'Ответ сервера не JSON ($status)'
            : (t.length > 280 ? '${t.substring(0, 280)}…' : t),
        statusCode: status,
      );
    }
    if (data is Map && data is! Map<String, dynamic>) {
      try {
        data = Map<String, dynamic>.from(data);
      } catch (_) {
        data = null;
      }
    }
    if (data is Map<String, dynamic>) {
      Map<String, dynamic>? asMap(dynamic v) {
        if (v is Map<String, dynamic>) return v;
        if (v is Map) {
          try {
            return Map<String, dynamic>.from(v);
          } catch (_) {}
        }
        return null;
      }

      final msgMap = asMap(data['message']);
      if (msgMap != null && msgMap['code'] == 'subscription_deactivated') {
        return ApiException(
          code: ApiErrorCode.subscriptionDeactivated,
          message: msgMap['message'] as String? ?? 'Подписка деактивирована. Обратитесь к администратору.',
          statusCode: status,
        );
      }

      final codeStr = data['code'] as String? ??
          (data.containsKey('error') && data['error'] is Map
              ? (data['error'] as Map)['code'] as String?
              : null);
      if (codeStr == 'subscription_deactivated') {
        return ApiException(
          code: ApiErrorCode.subscriptionDeactivated,
          message: data['message'] as String? ?? 'Подписка деактивирована. Обратитесь к администратору.',
          statusCode: status,
        );
      }
      if (data.containsKey('error') && data['error'] is Map) {
        final error = Map<String, dynamic>.from(data['error'] as Map);
        return ApiException(
          code: ApiErrorCode.fromString(error['code'] as String? ?? ''),
          message: error['message'] as String? ?? 'Ошибка',
          details: (error['details'] as List?)?.map((e) => e.toString()).toList(),
          statusCode: status,
        );
      }

      // NestJS: { "statusCode": 400, "message": "текст", "error": "Bad Request" }
      final nestMsg = data['message'];
      if (nestMsg is String && nestMsg.trim().isNotEmpty) {
        final sc = status;
        if (sc >= 400 && sc < 600) {
          final code = switch (sc) {
            400 => ApiErrorCode.validation,
            401 => ApiErrorCode.unauthorized,
            403 => ApiErrorCode.forbidden,
            404 => ApiErrorCode.notFound,
            409 => ApiErrorCode.conflict,
            429 => ApiErrorCode.rateLimit,
            _ => ApiErrorCode.unknown,
          };
          return ApiException(code: code, message: nestMsg.trim(), statusCode: sc);
        }
      }
      if (nestMsg is List && nestMsg.isNotEmpty) {
        final joined = nestMsg.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).join('\n');
        if (joined.isNotEmpty && status >= 400 && status < 500) {
          return ApiException(code: ApiErrorCode.validation, message: joined, statusCode: status);
        }
      }
    }
    switch (status) {
      case 400:
        return const ApiException(code: ApiErrorCode.validation, message: 'Некорректный запрос');
      case 401:
        return const ApiException(code: ApiErrorCode.unauthorized, message: 'Необходима авторизация');
      case 403:
        return const ApiException(code: ApiErrorCode.forbidden, message: 'Нет доступа');
      case 404:
        return const ApiException(code: ApiErrorCode.notFound, message: 'Не найдено');
      case 409:
        return const ApiException(code: ApiErrorCode.conflict, message: 'Конфликт данных');
      case 429:
        return const ApiException(code: ApiErrorCode.rateLimit, message: 'Слишком много запросов');
      default:
        return ApiException(code: ApiErrorCode.internal, message: 'Ошибка сервера ($status)');
    }
  }

  @override
  String toString() => 'ApiException(${code.code}: $message)';
}

sealed class Result<T> {
  const Result();
  factory Result.success(T data) = Success<T>;
  factory Result.failure(ApiException error) = Failure<T>;
  T? get dataOrNull => switch (this) { Success<T> s => s.data, Failure<T> _ => null };
  ApiException? get errorOrNull => switch (this) { Success<T> _ => null, Failure<T> f => f.error };

  R when<R>({required R Function(T data) success, required R Function(ApiException error) failure}) {
    return switch (this) {
      Success<T> s => success(s.data),
      Failure<T> f => failure(f.error),
    };
  }
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends Result<T> {
  final ApiException error;
  const Failure(this.error);
}
