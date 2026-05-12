import '../../../shared/models/order_model.dart';
import '../../api/api_exceptions.dart';
import '../../constants/mock_data.dart';
import '../order_repository.dart';

/// Мок-реализация OrderRepository
class MockOrderRepository implements OrderRepository {
  @override
  Future<Result<List<Order>>> getOrders({OrderStatus? status}) async {
    await _delay();
    var orders = List<Order>.from(MockData.orders);
    if (status != null) {
      orders = orders.where((o) => o.status == status).toList();
    }
    orders.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return Result.success(orders);
  }

  @override
  Future<Result<Order>> getOrderById(String id) async {
    await _delay();
    final order = MockData.findOrderById(id);
    if (order == null) {
      return Result.failure(const ApiException(
        code: ApiErrorCode.notFound,
        message: 'Заказ не найден',
      ));
    }
    return Result.success(order);
  }

  @override
  Future<Result<List<Order>>> getOrdersByCar(String carId) async {
    await _delay();
    final orders = MockData.orders.where((o) => o.carId == carId).toList()
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
    String? carPhotoUrl,
    List<ClientOrderLineDraft>? orderLineItems,
  }) async {
    await _delay(1000);

    final services = MockData.stoServices
        .where((s) => serviceIds.contains(s.id))
        .toList();

    final List<OrderItem> items;
    if (orderLineItems != null && orderLineItems.isNotEmpty) {
      var i = 0;
      items = orderLineItems
          .map(
            (e) => OrderItem(
              id: 'oi_${DateTime.now().millisecondsSinceEpoch}_${i++}',
              name: e.name,
              priceKopecks: e.priceKopecks,
              estimatedMinutes: e.estimatedMinutes,
            ),
          )
          .toList();
    } else {
      items = services.map((s) => OrderItem(
        id: 'oi_${DateTime.now().millisecondsSinceEpoch}_${s.id}',
        name: s.name,
        priceKopecks: s.priceKopecks,
        estimatedMinutes: s.durationMinutes,
        serviceId: s.id,
        catalogItemId: s.catalogItemId,
      )).toList();
    }

    final order = Order(
      id: 'order_${DateTime.now().millisecondsSinceEpoch}',
      orderNumber: 'AH-${(100000 + MockData.orders.length).toString()}',
      carId: carId,
      stoId: organizationId,
      stoName: 'Автосервис',
      status: OrderStatus.pendingConfirmation,
      dateTime: scheduledDate,
      items: items,
      comment: comment,
      carPhotoUrl: carPhotoUrl,
    );

    MockData.orders.insert(0, order);
    return Result.success(order);
  }

  @override
  Future<Result<void>> cancelOrder(String orderId, {String? reason}) async {
    await _delay();
    final index = MockData.orders.indexWhere((o) => o.id == orderId);
    if (index == -1) {
      return Result.failure(const ApiException(
        code: ApiErrorCode.notFound,
        message: 'Заказ не найден',
      ));
    }

    MockData.orders[index] = MockData.orders[index].copyWith(
      status: OrderStatus.cancelled,
    );
    return Result.success(null);
  }

  @override
  Future<Result<void>> confirmOrder(String orderId, {
    DateTime? dateTime,
    bool acceptProposed = true,
    String? approvalMessageId,
    List<String>? approvedItemIds,
    List<String>? rejectedItemIds,
  }) async {
    await _delay();
    return Result.success(null);
  }

  @override
  Future<Result<Order>> approveItems(String orderId, {
    required List<String> approvedItemIds,
    required List<String> rejectedItemIds,
    String? carId,
    String? approvalMessageId,
  }) async {
    await _delay(600);
    final index = MockData.orders.indexWhere((o) => o.id == orderId);
    if (index == -1) {
      return Result.failure(const ApiException(
        code: ApiErrorCode.notFound,
        message: 'Заказ не найден',
      ));
    }

    final order = MockData.orders[index];
    final updatedItems = order.items.map((item) {
      if (approvedItemIds.contains(item.id)) {
        return item.copyWith(isApproved: true);
      } else if (rejectedItemIds.contains(item.id)) {
        return item.copyWith(isRejected: true);
      }
      return item;
    }).toList();

    final updatedOrder = order.copyWith(
      items: updatedItems,
      status: OrderStatus.inProgress,
    );

    MockData.orders[index] = updatedOrder;
    return Result.success(updatedOrder);
  }

  @override
  Future<Result<void>> addReview(String orderId, {
    required int rating,
    String? text,
  }) async {
    await _delay(500);
    return Result.success(null);
  }

  Future<void> _delay([int ms = 300]) async {
    await Future.delayed(Duration(milliseconds: ms));
  }
}
