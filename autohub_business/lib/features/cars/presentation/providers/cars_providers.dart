import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/services/api_services_providers.dart';
import '../../../../core/repositories/order_repository.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../shared/models/car_aggregate.dart';
import '../../../../shared/models/car_transfer_insight.dart';

/// Список автомобилей, агрегированных из заказов.
final carsFromOrdersProvider = Provider<List<CarView>>((ref) {
  final orders = ref.watch(orderRepositoryProvider);
  return CarView.fromOrders(orders);
});

/// Данные о передаче владельца в клиентском приложении (по `car_id` из заказа).
final carTransferInsightProvider = FutureProvider.family<CarTransferInsight?, String>((ref, carId) async {
  final cid = carId.trim();
  if (cid.isEmpty || cid == 'unknown') return null;
  final orgId = ref.watch(authProvider.select((a) => a.user?.organizationId));
  if (orgId == null || orgId.isEmpty) return null;
  final api = ref.watch(organizationApiServiceProvider);
  final r = await api.getCarTransferInsight(orgId, cid);
  return r.dataOrNull;
});
