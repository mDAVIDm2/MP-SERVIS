import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/settings/filter_by_car_setting.dart';
import '../../../../shared/models/car_model.dart';
import '../../../../shared/models/order_model.dart';
import '../../../garage/presentation/widgets/order_card.dart';

class AllOrdersScreen extends ConsumerStatefulWidget {
  const AllOrdersScreen({super.key});

  @override
  ConsumerState<AllOrdersScreen> createState() => _AllOrdersScreenState();
}

class _AllOrdersScreenState extends ConsumerState<AllOrdersScreen> {
  int _tabIndex = 0;
  int _orgKindChipIndex = 0;

  static const List<({String? code, String label})> _orgKindChips = [
    (code: null, label: 'Все типы'),
    (code: 'sto', label: 'Автосервис'),
    (code: 'car_wash', label: 'Мойка'),
    (code: 'detailing', label: 'Детейлинг'),
    (code: 'tire_service', label: 'Шиномонтаж'),
    (code: 'body_shop', label: 'Кузовной'),
    (code: 'car_audio', label: 'Автозвук'),
    (code: 'glass', label: 'Стёкла'),
    (code: 'ev_service', label: 'EV'),
    (code: 'tuning', label: 'Тюнинг'),
    (code: 'other', label: 'Другое'),
  ];

  List<Order> get _filtered {
    var list = List<Order>.from(ref.watch(ordersProvider).valueOrNull ?? []);
    final filterByCar = ref.watch(filterByCarSettingProvider);
    if (filterByCar) {
      final carId = ref.watch(selectedCarIdProvider);
      if (carId != null) list = list.where((o) => o.carId == carId).toList();
    }
    final kindIdx = _orgKindChipIndex.clamp(0, _orgKindChips.length - 1);
    final kindCode = _orgKindChips[kindIdx].code;
    if (kindCode != null) {
      list = list.where((o) => o.organizationBusinessKind == kindCode).toList();
    }
    switch (_tabIndex) {
      case 0: return list.where((o) => o.status.isActive).toList();
      case 1: return list.where((o) => !o.status.isActive).toList();
      default: return list;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = _filtered..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.background,
        title: Text('Все заказы', style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w600,
        )),
      ),
      body: Column(
        children: [
          // Tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.palette.border),
              ),
              child: Row(
                children: [
                  _TabBtn(label: 'Активные', active: _tabIndex == 0,
                    onTap: () => setState(() => _tabIndex = 0)),
                  _TabBtn(label: 'Завершённые', active: _tabIndex == 1,
                    onTap: () => setState(() => _tabIndex = 1)),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              itemCount: _orgKindChips.length,
              separatorBuilder: (_, __) => SizedBox(width: 8),
              itemBuilder: (_, i) {
                final active = i == _orgKindChipIndex.clamp(0, _orgKindChips.length - 1);
                return GestureDetector(
                  onTap: () => setState(() => _orgKindChipIndex = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active ? context.palette.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: active ? context.palette.primary : context.palette.border),
                    ),
                    child: Text(
                      _orgKindChips[i].label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: active ? context.palette.onAccent : context.palette.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: orders.isEmpty
                ? Center(
                    child: Text('Нет заказов', style: TextStyle(
                      fontSize: 16, color: context.palette.textSecondary,
                    )),
                  )
                : RefreshIndicator(
                    onRefresh: () => ref.read(ordersProvider.notifier).loadOrders(),
                    color: context.palette.primary,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: orders.length,
                      separatorBuilder: (_, __) => SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final order = orders[i];
                        final cars = ref.watch(carsProvider).valueOrNull ?? [];
                        final car = cars.isEmpty
                            ? Car(id: order.carId, brand: '—', model: '', year: 0, mileage: 0)
                            : cars.firstWhere(
                                (c) => c.id == order.carId,
                                orElse: () => cars.first,
                              );
                        return OrderCard(
                          order: order,
                          car: car,
                          onReturnFromDetail: () => ref.read(ordersProvider.notifier).loadOrders(),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? context.palette.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(label, style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: active ? context.palette.onAccent : context.palette.textSecondary,
          )),
        ),
      ),
    );
  }
}
