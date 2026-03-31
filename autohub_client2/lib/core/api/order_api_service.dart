import 'package:dio/dio.dart';
import 'api_client.dart';
import 'api_endpoints.dart';
import 'api_exceptions.dart';

/// Заказы и отмена (клиент видит свои заказы по телефону).
class OrderApiService {
  OrderApiService(this._client);
  final ApiClient _client;

  Future<Result<Map<String, dynamic>>> getOrders() async {
    try {
      final res = await _client.get(ApiEndpoints.orders);
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      }
      return Result.success(data);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<Map<String, dynamic>>> getOrder(String id) async {
    try {
      final res = await _client.get(ApiEndpoints.order(id));
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      }
      return Result.success(data);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// Получить chat_id по заказу (GET /orders/:orderId/chat). Для открытия «правильного» чата по orderId.
  Future<Result<String>> getChatIdForOrder(String orderId) async {
    try {
      final res = await _client.get(ApiEndpoints.orderChat(orderId));
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      }
      final chatId = data['chat_id'] as String? ?? data['chatId'] as String?;
      if (chatId == null || chatId.isEmpty) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Нет chat_id в ответе'));
      }
      return Result.success(chatId);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<void>> cancelOrder(String id) async {
    try {
      await _client.post(ApiEndpoints.orderCancel(id));
      return Result.success(null);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// Согласовать/отклонить доп. работы по заказу (клиент). Переводит заказ в статус confirmed.
  /// [carId] — при подтверждении заказа «для всех машин» указываем активную машину из гаража.
  Future<Result<Map<String, dynamic>>> approveOrderItems(
    String orderId, {
    required List<String> approvedItemIds,
    required List<String> rejectedItemIds,
    String? carId,
    String? approvalMessageId,
  }) async {
    try {
      final data = <String, dynamic>{
        'approved_item_ids': approvedItemIds,
        'rejected_item_ids': rejectedItemIds,
      };
      if (carId != null && carId.isNotEmpty) data['car_id'] = carId;
      if (approvalMessageId != null && approvalMessageId.isNotEmpty) {
        data['approval_message_id'] = approvalMessageId;
      }
      final res = await _client.post(ApiEndpoints.orderApproval(orderId), data: data);
      final resData = res.data;
      if (resData is! Map<String, dynamic>) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      }
      return Result.success(resData);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// Подтвердить заказ клиентом. [acceptProposed] true — согласие с предложением (время/без), false — клиент указал своё время (сервис подтвердит снова).
  Future<Result<void>> confirmOrder(
    String orderId, {
    DateTime? dateTime,
    bool acceptProposed = true,
    String? approvalMessageId,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (dateTime != null) body['date_time'] = dateTime.toUtc().toIso8601String();
      body['accept_proposed'] = acceptProposed;
      if (approvalMessageId != null && approvalMessageId.isNotEmpty) {
        body['approval_message_id'] = approvalMessageId;
      }
      await _client.post(ApiEndpoints.orderConfirm(orderId), data: body);
      return Result.success(null);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// Создание заказа от клиента (запись в организацию). Body: organization_id, car_id, car_info, date_time, items[], comment.
  Future<Result<Map<String, dynamic>>> createOrderFromClient(Map<String, dynamic> body) async {
    try {
      final res = await _client.post(ApiEndpoints.orders, data: body);
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      }
      return Result.success(data);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }
}
