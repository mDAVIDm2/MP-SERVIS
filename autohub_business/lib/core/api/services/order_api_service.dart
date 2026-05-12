import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../api_client.dart';
import '../api_endpoints.dart';
import '../api_exceptions.dart';
import '../../../shared/models/order_model.dart';

/// Сервис заказов — реальный HTTP API.
class OrderApiService {
  OrderApiService(this._client);

  final ApiClient _client;

  /// Удалить все заказы в БД (и при необходимости связанные чаты — на стороне бэкенда).
  Future<Result<void>> deleteAllOrders({CancelToken? cancelToken}) async {
    try {
      await _client.post(ApiEndpoints.ordersClearAll, cancelToken: cancelToken);
      return Result.success(null);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<List<Order>>> getOrders({CancelToken? cancelToken}) async {
    try {
      final res = await _client.get(ApiEndpoints.orders, cancelToken: cancelToken);
      final data = res.data;
      if (data is! Map<String, dynamic>) return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      final list = data['items'] as List<dynamic>? ?? data['data'] as List<dynamic>? ?? [];
      final orders = list.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
      return Result.success(orders);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<Order>> getOrder(String id) async {
    try {
      final res = await _client.get(ApiEndpoints.order(id));
      final data = res.data;
      if (data is! Map<String, dynamic>) return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      return Result.success(Order.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<Order>> createOrder({
    required String carId,
    required String carInfo,
    required DateTime dateTime,
    required List<OrderItem> items,
    String? clientName,
    String? clientPhone,
    String? comment,
    String? vin,
    String? licensePlate,
    String? bodyType,
    String? color,
    int? mileage,
    String? engineType,
    String? bayId,
    bool confirmForClient = false,
  }) async {
    try {
      final body = {
        'car_id': carId,
        'car_info': carInfo,
        'date_time': dateTime.toUtc().toIso8601String(),
        'items': items.map((i) => {
          'name': i.name,
          'price_kopecks': i.priceKopecks,
          'estimated_minutes': i.estimatedMinutes,
          if (i.serviceId != null && i.serviceId!.trim().isNotEmpty) 'service_id': i.serviceId!.trim(),
          if (i.catalogItemId != null && i.catalogItemId!.trim().isNotEmpty)
            'catalog_item_id': i.catalogItemId!.trim(),
        }).toList(),
        if (clientName != null) 'client_name': clientName,
        if (clientPhone != null) 'client_phone': clientPhone,
        if (comment != null) 'comment': comment,
        if (vin != null && vin.isNotEmpty) 'vin': vin,
        if (licensePlate != null && licensePlate.isNotEmpty) 'license_plate': licensePlate,
        if (bodyType != null && bodyType.isNotEmpty) 'body_type': bodyType,
        if (color != null && color.isNotEmpty) 'color': color,
        if (mileage != null) 'mileage': mileage,
        if (engineType != null && engineType.isNotEmpty) 'engine_type': engineType,
        if (bayId != null && bayId.isNotEmpty) 'bay_id': bayId,
        if (confirmForClient) 'confirm_for_client': true,
      };
      final res = await _client.post(ApiEndpoints.orders, data: body);
      final data = res.data;
      if (data is! Map<String, dynamic>) return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      return Result.success(Order.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// Преобразует OrderStatus в snake_case для API (backend ожидает pending_approval, не pendingApproval).
  static String _statusToApi(OrderStatus status) {
    return status.name.replaceAllMapped(RegExp(r'([A-Z])'), (m) => '_${m.group(0)!.toLowerCase()}').replaceFirst(RegExp(r'^_'), '');
  }

  Future<Result<void>> setOrderStatus(String id, OrderStatus status) async {
    try {
      await _client.patch(ApiEndpoints.orderStatus(id), data: {'status': _statusToApi(status)});
      return Result.success(null);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// Частичное обновление: передавайте только нужные ключи (`master_id`, `bay_id`).
  Future<Result<void>> patchOrderAssignment(String orderId, Map<String, dynamic> body) async {
    try {
      await _client.post(ApiEndpoints.orderAssignMaster(orderId), data: body);
      return Result.success(null);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<void>> assignMaster(String orderId, String? masterId) async {
    return patchOrderAssignment(orderId, <String, dynamic>{'master_id': masterId});
  }

  /// Ручная корректировка планового времени заказа (С / По).
  Future<Result<void>> updateOrderTime(String orderId, {DateTime? plannedStartTime, DateTime? plannedEndTime}) async {
    try {
      final body = <String, dynamic>{};
      if (plannedStartTime != null) body['planned_start_time'] = plannedStartTime.toUtc().toIso8601String();
      if (plannedEndTime != null) body['planned_end_time'] = plannedEndTime.toUtc().toIso8601String();
      await _client.patch(ApiEndpoints.orderTime(orderId), data: body);
      return Result.success(null);
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

  /// Удалить заказ из БД (допустимо только для отменённых/завершённых). DELETE /orders/:id
  Future<Result<void>> deleteOrder(String id) async {
    try {
      await _client.delete(ApiEndpoints.order(id));
      return Result.success(null);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// Скрыть заказ из отображения у пользователя (в БД сохраняется с пометкой hidden_from_user).
  Future<Result<void>> hideOrderFromUser(String id) async {
    try {
      await _client.patch(ApiEndpoints.order(id), data: {'hidden_from_user': true});
      return Result.success(null);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// Получить или создать чат по заказу (для отправки согласования из приложения для бизнеса).
  Future<Result<String>> getChatForOrder(String orderId) async {
    try {
      final res = await _client.get(ApiEndpoints.orderChat(orderId));
      final data = res.data;
      if (data is! Map<String, dynamic>) return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      final chatId = data['chat_id'] as String?;
      if (chatId == null || chatId.isEmpty) return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Нет chat_id в ответе'));
      return Result.success(chatId);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// Организация подтверждает согласование за клиента («подтвердить по телефону»). Применяет черновик и восстанавливает статус.
  Future<Result<Order>> confirmOrderByPhone(String orderId) async {
    try {
      final res = await _client.post(ApiEndpoints.orderConfirmByPhone(orderId));
      final data = res.data;
      if (data is! Map<String, dynamic>) return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      final orderMap = data['order'] as Map<String, dynamic>? ?? data['data'] as Map<String, dynamic>? ?? data;
      return Result.success(Order.fromJson(Map<String, dynamic>.from(orderMap)));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// Привязка материала склада к заказу (план; резерв при подтверждённом заказе — на бэкенде).
  Future<Result<void>> addOrderInventoryLine(
    String orderId, {
    required String inventoryItemId,
    required double quantity,
    String? unit,
    String? orderItemId,
  }) async {
    try {
      final body = <String, dynamic>{
        'inventory_item_id': inventoryItemId,
        'quantity': quantity,
        if (unit != null && unit.trim().isNotEmpty) 'unit': unit.trim(),
        if (orderItemId != null && orderItemId.trim().isNotEmpty) 'order_item_id': orderItemId.trim(),
      };
      await _client.post(ApiEndpoints.orderInventoryLines(orderId), data: body);
      return Result.success(null);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// PATCH позиций заказа (отметка выполнения, доп. работы и т.д.).
  Future<Result<Order>> patchOrderItems(String orderId, List<OrderItem> items) async {
    try {
      final body = {
        'items': items.map((i) => {
          'id': i.id,
          'name': i.name,
          if (i.priceKopecks != null) 'price_kopecks': i.priceKopecks,
          'estimated_minutes': i.estimatedMinutes,
          'is_completed': i.isCompleted,
          'is_additional': i.isAdditional,
          if (i.serviceId != null && i.serviceId!.trim().isNotEmpty) 'service_id': i.serviceId!.trim(),
          if (i.catalogItemId != null && i.catalogItemId!.trim().isNotEmpty)
            'catalog_item_id': i.catalogItemId!.trim(),
        }).toList(),
      };
      final res = await _client.patch(ApiEndpoints.orderItems(orderId), data: body);
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      }
      return Result.success(Order.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// Список фото по заказу.
  Future<Result<List<OrderPhoto>>> getOrderPhotos(String orderId) async {
    try {
      final res = await _client.get(ApiEndpoints.orderPhotos(orderId));
      final data = res.data;
      if (data is! Map<String, dynamic>) return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат'));
      final list = data['items'] as List<dynamic>? ?? [];
      final photos = list.map((e) => OrderPhoto.fromJson(e as Map<String, dynamic>)).toList();
      return Result.success(photos);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// Загрузить фото по заказу (multipart). [fileBytes] — байты изображения, [fileName] — например photo.jpg.
  Future<Result<OrderPhoto>> uploadOrderPhoto(String orderId, List<int> fileBytes, String fileName) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
      });
      final res = await _client.post<dynamic>(ApiEndpoints.orderPhotos(orderId), data: formData, options: Options(
        contentType: 'multipart/form-data',
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
      ));
      final data = res.data;
      if (data is! Map<String, dynamic>) return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ'));
      return Result.success(OrderPhoto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// Скачать файл фото по заказу (с авторизацией). Для отображения в Image.memory.
  Future<Result<Uint8List>> getOrderPhotoBytes(String orderId, String photoId) async {
    final path = ApiEndpoints.orderPhotoFile(orderId, photoId);
    final result = await _client.getBytes(path);
    return result.when(
      success: (bytes) => Result.success(Uint8List.fromList(bytes)),
      failure: (e) => Result.failure(e),
    );
  }

  /// Доступные слоты на дату для организации (запрос согласования — выбор времени).
  Future<Result<AvailableSlotsResult>> getAvailableSlots(
    String organizationId,
    DateTime date, [
    List<String> serviceIds = const [],
  ]) async {
    try {
      final body = {
        'organization_id': organizationId,
        'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        if (serviceIds.isNotEmpty) 'service_ids': serviceIds,
      };
      final res = await _client.post(ApiEndpoints.bookingAvailableSlots, data: body);
      final data = res.data;
      if (data is! Map<String, dynamic>) return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      final slotsRaw = data['slots'] as List<dynamic>? ?? [];
      int hm(String? s, int fallback) {
        if (s == null || s.isEmpty) return fallback;
        final p = s.split(':');
        final h = int.tryParse(p[0].trim()) ?? 0;
        final m = p.length > 1 ? (int.tryParse(p[1].trim()) ?? 0) : 0;
        return (h * 60 + m).clamp(0, 24 * 60);
      }

      final slotDur = ((data['slot_duration_minutes'] as num?)?.toInt() ?? 30).clamp(15, 240);
      final ws = hm(data['work_day_start'] as String?, 9 * 60);
      var we = hm(data['work_day_end'] as String?, 20 * 60);
      if (we < ws) we = ws + 60;
      final startTimes = <String>{};
      for (final s in slotsRaw) {
        final m = s as Map<String, dynamic>;
        final start = m['start']?.toString();
        if (start != null && start.isNotEmpty) {
          final dt = DateTime.tryParse(start);
          if (dt != null) {
            final local = dt.toLocal();
            startTimes.add('${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}');
          }
        }
      }
      return Result.success(AvailableSlotsResult(
        startTimes: startTimes.toList()..sort(),
        slotDurationMinutes: slotDur,
        workStartMinutes: ws,
        workEndMinutes: we,
      ));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }
}
