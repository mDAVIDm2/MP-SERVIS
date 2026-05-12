import 'order_model.dart';

/// Агрегат «автомобиль» — собирается из заказов (машина закрепляется за клиентом через заказы).
/// Один и тот же автомобиль может фигурировать в нескольких заказах; здесь — сводка по нему.
class CarView {
  /// Уникальный ключ: carId из заказа или сгенерированный из carInfo+vin.
  final String id;
  /// Марка, модель, госномер (как в заказе).
  final String carInfo;
  final String? vin;
  final String? licensePlate;
  final String? bodyType;
  final String? color;
  final int? mileage;
  final String? engineType;
  /// Имя клиента (из последнего или частого заказа).
  final String? clientName;
  /// Телефон клиента.
  final String? clientPhone;
  /// Фото авто из любого заказа, где клиент передал URL.
  final String? carPhotoUrl;
  /// Все заказы по этой машине (от новых к старым).
  final List<Order> orders;

  const CarView({
    required this.id,
    required this.carInfo,
    this.vin,
    this.licensePlate,
    this.bodyType,
    this.color,
    this.mileage,
    this.engineType,
    this.clientName,
    this.clientPhone,
    this.carPhotoUrl,
    required this.orders,
  });

  int get orderCount => orders.length;
  int get totalKopecks => orders.fold<int>(0, (s, o) => s + o.totalKopecks);
  Order? get lastOrder => orders.isNotEmpty ? orders.first : null;
  DateTime? get lastOrderDate => lastOrder?.effectiveDateTime;

  /// Выполнено (completed + done).
  int get completedCount =>
      orders.where((o) => o.status == OrderStatus.completed || o.status == OrderStatus.done).length;
  /// Отменено.
  int get cancelledCount => orders.where((o) => o.status == OrderStatus.cancelled).length;
  /// В работе / ожидании (активные).
  int get pendingCount => orders.where((o) => o.status.isActive).length;
  /// Сумма доп. работ по всем заказам (копейки).
  int get additionalKopecks => orders.fold<int>(
        0,
        (s, o) =>
            s +
            o.items
                .where((i) => i.isAdditional && i.priceKopecks != null)
                .fold<int>(0, (sum, i) => sum + (i.priceKopecks ?? 0)),
      );
  /// Ближайший предстоящий визит (активный заказ в будущем).
  Order? get nextVisit {
    final now = DateTime.now();
    final active = orders.where((o) => o.status.isActive).toList();
    Order? nearest;
    DateTime? nearestDate;
    for (final o in active) {
      final d = o.plannedStartTime ?? o.dateTime ?? o.effectiveDateTime;
      if (d.isAfter(now) && (nearestDate == null || d.isBefore(nearestDate))) {
        nearestDate = d;
        nearest = o;
      }
    }
    return nearest;
  }

  /// URL фото для карточки заказа: сначала с самого заказа, иначе — с любого другого заказа по тому же [Order.carId]
  /// (как в клиентском приложении: снимок в гараже может быть только на части заказов).
  static String? resolveCarPhotoUrlForOrder(Order order, List<Order> allOrders) {
    final direct = order.carPhotoUrl?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final cid = order.carId.trim();
    if (cid.isEmpty || cid == 'unknown') return null;
    for (final o in allOrders) {
      if (o.id == order.id) continue;
      if (o.carId.trim() != cid) continue;
      final u = o.carPhotoUrl?.trim();
      if (u != null && u.isNotEmpty) return u;
    }
    return null;
  }

  /// Собирает уникальные автомобили из списка заказов (по carId или carInfo+vin).
  static List<CarView> fromOrders(List<Order> orders) {
    final byKey = <String, List<Order>>{};
    for (final o in orders) {
      final key = o.carId.isNotEmpty
          ? o.carId
          : '${o.carInfo}|${o.vin ?? ''}';
      byKey.putIfAbsent(key, () => []).add(o);
    }
    for (final list in byKey.values) {
      list.sort((a, b) => (b.effectiveDateTime).compareTo(a.effectiveDateTime));
    }
    final cars = <CarView>[];
    for (final entry in byKey.entries) {
      final list = entry.value;
      final first = list.first;
      final clientName = first.clientName;
      final clientPhone = first.clientPhone;
      String? photo;
      for (final o in list) {
        final u = o.carPhotoUrl?.trim();
        if (u != null && u.isNotEmpty) {
          photo = u;
          break;
        }
      }
      cars.add(CarView(
        id: entry.key,
        carInfo: first.carInfo,
        vin: first.vin,
        licensePlate: first.licensePlate,
        bodyType: first.bodyType,
        color: first.color,
        mileage: first.mileage,
        engineType: first.engineType,
        clientName: clientName,
        clientPhone: clientPhone,
        carPhotoUrl: photo,
        orders: list,
      ));
    }
    cars.sort((a, b) {
      final da = a.lastOrderDate ?? DateTime.utc(0);
      final db = b.lastOrderDate ?? DateTime.utc(0);
      return db.compareTo(da);
    });
    return cars;
  }
}
