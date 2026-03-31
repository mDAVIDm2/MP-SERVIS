import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/repositories/order_repository.dart';
import '../../../../shared/models/car_aggregate.dart';

/// Список автомобилей, агрегированных из заказов.
final carsFromOrdersProvider = Provider<List<CarView>>((ref) {
  final orders = ref.watch(orderRepositoryProvider);
  return CarView.fromOrders(orders);
});
