import 'package:dio/dio.dart';

import 'api_client.dart';
import 'api_endpoints.dart';
import 'api_exceptions.dart';

/// Передача автомобиля между клиентами (`/profile/car-transfers`).
class CarTransferApiService {
  CarTransferApiService(this._client);

  final ApiClient _client;

  Future<Result<List<Map<String, dynamic>>>> listIncoming() async {
    try {
      final res = await _client.get<Map<String, dynamic>>(ApiEndpoints.profileCarTransfersIncoming);
      final raw = (res.data?['items'] as List<dynamic>?) ?? [];
      return Result.success(raw.map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<List<Map<String, dynamic>>>> listOutgoing() async {
    try {
      final res = await _client.get<Map<String, dynamic>>(ApiEndpoints.profileCarTransfersOutgoing);
      final raw = (res.data?['items'] as List<dynamic>?) ?? [];
      return Result.success(raw.map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<Map<String, dynamic>>> create({
    required String carId,
    required String toPhone,
    Map<String, dynamic>? options,
  }) async {
    try {
      final res = await _client.post<Map<String, dynamic>>(
        ApiEndpoints.profileCarTransfers,
        data: {
          'car_id': carId,
          'to_phone': toPhone,
          if (options != null && options.isNotEmpty) 'options': options,
        },
      );
      final data = res.data;
      if (data == null) {
        return Result.failure(
          const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ сервера'),
        );
      }
      return Result.success(data);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<Map<String, dynamic>>> accept(String transferId) async {
    try {
      final res = await _client.post<Map<String, dynamic>>(ApiEndpoints.profileCarTransferAccept(transferId));
      final data = res.data;
      if (data == null) {
        return Result.failure(
          const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ сервера'),
        );
      }
      return Result.success(data);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<Map<String, dynamic>>> reject(String transferId) async {
    try {
      final res = await _client.post<Map<String, dynamic>>(ApiEndpoints.profileCarTransferReject(transferId));
      final data = res.data;
      if (data == null) {
        return Result.failure(
          const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ сервера'),
        );
      }
      return Result.success(data);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<Map<String, dynamic>>> cancel(String transferId) async {
    try {
      final res = await _client.post<Map<String, dynamic>>(ApiEndpoints.profileCarTransferCancel(transferId));
      final data = res.data;
      if (data == null) {
        return Result.failure(
          const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ сервера'),
        );
      }
      return Result.success(data);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<void>> forgetFormer(String carId) async {
    try {
      await _client.delete(ApiEndpoints.profileCarForgetFormer(carId));
      return Result.success(null);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }
}
