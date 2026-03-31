import '../../shared/models/order_model.dart';
import '../api/api_exceptions.dart';

/// Абстрактный репозиторий заказов
abstract class OrderRepository {
  /// Все заказы пользователя
  Future<Result<List<Order>>> getOrders({OrderStatus? status});

  /// Заказ по ID
  Future<Result<Order>> getOrderById(String id);

  /// Заказы для конкретного авто
  Future<Result<List<Order>>> getOrdersByCar(String carId);

  /// Создать заказ (бронирование)
  Future<Result<Order>> createOrder({
    required String carId,
    required String organizationId,
    required List<String> serviceIds,
    required DateTime scheduledDate,
    required String scheduledTime,
    /// С сервера слотов (точнее локального времени). Если задан — [scheduledDate]/[scheduledTime] игнорируются для date_time.
    DateTime? scheduledStartUtc,
    String? masterId,
    String? comment,
    /// Строка для отображения (марка, модель, год) — передаётся в API как car_info
    String? carInfo,
    String? vin,
    String? licensePlate,
    String? bodyType,
    String? color,
    int? mileage,
    String? engineType,
  });

  /// Отменить заказ
  Future<Result<void>> cancelOrder(String orderId, {String? reason});

  /// Подтвердить заказ клиентом. [acceptProposed] true — согласие с предложением, false — клиент указал своё время (сервис подтвердит снова).
  Future<Result<void>> confirmOrder(String orderId, {
    DateTime? dateTime,
    bool acceptProposed = true,
    String? approvalMessageId,
  });

  /// Согласовать доп. работы. [carId] — при заказе «для всех машин» передаём активную машину из гаража.
  /// [approvalMessageId] — id карточки согласования в чате (нужен при нескольких запросах подряд).
  Future<Result<Order>> approveItems(String orderId, {
    required List<String> approvedItemIds,
    required List<String> rejectedItemIds,
    String? carId,
    String? approvalMessageId,
  });

  /// Оставить отзыв
  Future<Result<void>> addReview(String orderId, {
    required int rating,
    String? text,
  });
}
