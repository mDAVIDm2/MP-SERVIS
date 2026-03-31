import '../../shared/models/order_model.dart';
import '../api/api_exceptions.dart';
import '../api/order_api_service.dart';
import 'order_repository.dart';
import 'sto_repository.dart';

/// Репозиторий заказов через API (общий бэкенд с Business).
class ApiOrderRepository implements OrderRepository {
  ApiOrderRepository(this._api, this._stoRepo);
  final OrderApiService _api;
  final STORepository _stoRepo;

  @override
  Future<Result<List<Order>>> getOrders({OrderStatus? status}) async {
    final result = await _api.getOrders();
    final data = result.dataOrNull;
    if (data == null) return Result.failure(result.errorOrNull!);
    final list = (data['items'] as List<dynamic>?) ?? [];
    var orders = list
        .map((e) => Order.fromApiJson(e as Map<String, dynamic>))
        .toList();
    if (status != null) {
      orders = orders.where((o) => o.status == status).toList();
    }
    orders.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return Result.success(orders);
  }

  @override
  Future<Result<Order>> getOrderById(String id) async {
    final result = await _api.getOrder(id);
    final data = result.dataOrNull;
    if (data == null) return Result.failure(result.errorOrNull!);
    return Result.success(Order.fromApiJson(data));
  }

  @override
  Future<Result<List<Order>>> getOrdersByCar(String carId) async {
    final result = await _api.getOrders();
    final data = result.dataOrNull;
    if (data == null) return Result.failure(result.errorOrNull!);
    final list = (data['items'] as List<dynamic>?) ?? [];
    final orders =
        list
            .map((e) => Order.fromApiJson(e as Map<String, dynamic>))
            .where((o) => o.carId == carId)
            .toList()
          ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return Result.success(orders);
  }

  @override
  Future<Result<Order>> createOrder({
    required String carId,
    required String organizationId,
    required List<String> serviceIds,
    required DateTime scheduledDate,
    required String scheduledTime,
    DateTime? scheduledStartUtc,
    String? masterId,
    String? comment,
    String? carInfo,
    String? vin,
    String? licensePlate,
    String? bodyType,
    String? color,
    int? mileage,
    String? engineType,
  }) async {
    final servicesResult = await _stoRepo.getServices(organizationId);
    final services = servicesResult.dataOrNull;
    if (services == null) return Result.failure(servicesResult.errorOrNull!);
    final selected = services.where((s) => serviceIds.contains(s.id)).toList();
    if (selected.length != serviceIds.length) {
      return Result.failure(
        const ApiException(
          code: ApiErrorCode.internal,
          message:
              'Не все выбранные услуги найдены. Обновите страницу и попробуйте снова.',
        ),
      );
    }
    final items = selected
        .map(
          (s) => <String, dynamic>{
            'name': s.name,
            'price_kopecks': s.effectivePriceKopecks(bodyType),
            'estimated_minutes': s.effectiveDurationMinutes(bodyType),
          },
        )
        .toList();
    final DateTime dateTime;
    if (scheduledStartUtc != null) {
      dateTime = scheduledStartUtc.toUtc();
    } else {
      final parts = scheduledTime.split(':');
      final hour = int.tryParse(parts.first) ?? 0;
      final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      dateTime = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        hour,
        minute,
      ).toUtc();
    }
    final body = <String, dynamic>{
      'organization_id': organizationId,
      'car_id': carId,
      'car_info': carInfo ?? '',
      'date_time': dateTime.toIso8601String(),
      'items': items,
      if (masterId != null && masterId.isNotEmpty) 'master_id': masterId,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
      if (vin != null && vin.isNotEmpty) 'vin': vin,
      if (licensePlate != null && licensePlate.isNotEmpty)
        'license_plate': licensePlate,
      if (bodyType != null && bodyType.isNotEmpty) 'body_type': bodyType,
      if (color != null && color.isNotEmpty) 'color': color,
      if (mileage != null) 'mileage': mileage,
      if (engineType != null && engineType.isNotEmpty)
        'engine_type': engineType,
    };
    final result = await _api.createOrderFromClient(body);
    final data = result.dataOrNull;
    if (data == null) return Result.failure(result.errorOrNull!);
    return Result.success(Order.fromApiJson(data));
  }

  @override
  Future<Result<void>> cancelOrder(String orderId, {String? reason}) async {
    final result = await _api.cancelOrder(orderId);
    return result.errorOrNull == null
        ? Result.success(null)
        : Result.failure(result.errorOrNull!);
  }

  @override
  Future<Result<void>> confirmOrder(
    String orderId, {
    DateTime? dateTime,
    bool acceptProposed = true,
    String? approvalMessageId,
  }) async {
    final result = await _api.confirmOrder(
      orderId,
      dateTime: dateTime,
      acceptProposed: acceptProposed,
      approvalMessageId: approvalMessageId,
    );
    return result.errorOrNull == null
        ? Result.success(null)
        : Result.failure(result.errorOrNull!);
  }

  @override
  Future<Result<Order>> approveItems(
    String orderId, {
    required List<String> approvedItemIds,
    required List<String> rejectedItemIds,
    String? carId,
    String? approvalMessageId,
  }) async {
    final result = await _api.approveOrderItems(
      orderId,
      approvedItemIds: approvedItemIds,
      rejectedItemIds: rejectedItemIds,
      carId: carId,
      approvalMessageId: approvalMessageId,
    );
    final data = result.dataOrNull;
    if (data == null) return Result.failure(result.errorOrNull!);
    return Result.success(Order.fromApiJson(data));
  }

  @override
  Future<Result<void>> addReview(
    String orderId, {
    required int rating,
    String? text,
  }) async {
    return Result.failure(
      const ApiException(
        code: ApiErrorCode.internal,
        message: 'Отзыв через API пока не реализован',
      ),
    );
  }
}
