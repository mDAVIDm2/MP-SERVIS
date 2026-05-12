import 'package:dio/dio.dart';

import '../../../shared/models/inventory_models.dart';
import '../api_client.dart';
import '../api_endpoints.dart';
import '../api_exceptions.dart';

class InventoryApiService {
  InventoryApiService(this._client);

  final ApiClient _client;

  Future<Result<List<InventoryItemModel>>> listItems({CancelToken? cancelToken}) async {
    try {
      final res = await _client.get(ApiEndpoints.inventoryItems, cancelToken: cancelToken);
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      }
      final list = data['items'] as List<dynamic>? ?? [];
      final items = list.map((e) => InventoryItemModel.fromJson(e as Map<String, dynamic>)).toList();
      return Result.success(items);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<List<InventoryMovementModel>>> listRecentMovements({int limit = 150, CancelToken? cancelToken}) async {
    try {
      final res = await _client.get(
        '${ApiEndpoints.inventoryMovements}?limit=$limit',
        cancelToken: cancelToken,
      );
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      }
      final list = data['items'] as List<dynamic>? ?? [];
      final items = list.map((e) => InventoryMovementModel.fromJson(e as Map<String, dynamic>)).toList();
      return Result.success(items);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<InventoryItemModel>> createItem({
    required String name,
    String unit = 'pcs',
    String itemType = 'material',
    double? initialQuantity,
    CancelToken? cancelToken,
  }) async {
    try {
      final body = <String, dynamic>{
        'name': name,
        'unit': unit,
        'item_type': itemType,
        if (initialQuantity != null && initialQuantity > 0) 'initial_quantity': initialQuantity,
      };
      final res = await _client.post(ApiEndpoints.inventoryItems, data: body, cancelToken: cancelToken);
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      }
      return Result.success(InventoryItemModel.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<InventoryItemModel>> postReceipt({
    required String itemId,
    required double quantity,
    String? comment,
    CancelToken? cancelToken,
  }) async {
    try {
      final res = await _client.post(
        ApiEndpoints.inventoryItemReceipt(itemId),
        data: {
          'quantity': quantity,
          if (comment != null && comment.isNotEmpty) 'comment': comment,
        },
        cancelToken: cancelToken,
      );
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      }
      return Result.success(InventoryItemModel.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }
}
