import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/l10n/l10n_scope.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/theme/app_design_system.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/settings/filter_by_car_setting.dart';
import '../../../profile/presentation/screens/maintenance_reminders_screen.dart';
import '../../../../core/settings/garage_maintenance_onboarding_provider.dart';
import '../../../../core/settings/maintenance_reminders_provider.dart';
import '../../../profile/presentation/widgets/car_maintenance_reminders_section.dart';
import '../widgets/garage_maintenance_recommendations_block.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/settings/favorite_sto_ids_provider.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/car_model.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/models/sto_model.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../orders/presentation/screens/all_orders_screen.dart';
import '../../../orders/presentation/screens/order_detail_screen.dart';
import '../../../search/presentation/screens/sto_detail_screen.dart';
import '../screens/add_car_screen.dart';
import '../screens/car_detail_screen.dart';
import '../screens/car_photo_detail_screen.dart';
import '../widgets/car_card.dart';
import '../widgets/reminder_card.dart';
import '../widgets/order_card.dart';
import '../widgets/mileage_update_sheet.dart';
import '../widgets/garage_cars_list_sheet.dart';

class GarageScreen extends ConsumerStatefulWidget {
  const GarageScreen({super.key});

  @override
  ConsumerState<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends ConsumerState<GarageScreen> {
  int _currentCarIndex = 0;
  late final PageController _carPageController;
  /// После успешного добавления авто — показать предложение настроить напоминания о ТО.
  String? _remindersOnboardingCarId;

  List<Car> get cars => ref.watch(carsProvider).valueOrNull ?? [];
  Car? get currentCarOrNull => cars.isNotEmpty ? cars[_currentCarIndex] : null;
  Car get currentCar => currentCarOrNull ?? Car(id: '', brand: '', model: '', year: 0, mileage: 0);

  List<Order> get _ordersList => ref.watch(ordersProvider).valueOrNull ?? [];

  /// Заказы для отображения: по выбранному авто или по всем (согласно настройке).
  List<Order> get _ordersForFilter {
    final filterByCar = ref.watch(filterByCarSettingProvider);
    final selectedId = ref.watch(selectedCarIdProvider);
    if (!filterByCar) return List<Order>.from(_ordersList);
    final carId = selectedId ?? currentCar.id;
    return _ordersList.where((o) => o.carId == carId).toList();
  }

  List<Order> get recentOrders {
    final filterByCar = ref.watch(filterByCarSettingProvider);
    final list = filterByCar
        ? _ordersList.where((o) => o.carId == currentCar.id).toList()
        : List<Order>.from(_ordersList);
    list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return list;
  }

  int get monthExpenses => _ordersForFilter
      .where((o) => o.status == OrderStatus.done &&
          o.dateTime.month == DateTime.now().month &&
          o.dateTime.year == DateTime.now().year)
      .fold(0, (sum, o) => sum + o.totalKopecks);

  Order? get lastOrder {
    final list = List<Order>.from(_ordersForFilter)..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return list.isNotEmpty ? list.first : null;
  }

  @override
  void initState() {
    super.initState();
    _carPageController = PageController(initialPage: 0, viewportFraction: 1.0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(unreadNotificationCountProvider);
      ref.invalidate(unreadByCarProvider);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPageToSelectedCar();
  }

  /// Синхронизирует PageView и _currentCarIndex с сохранённым selectedCarId (важно при возврате на вкладку).
  void _syncPageToSelectedCar() {
    final list = ref.read(carsProvider).valueOrNull ?? [];
    if (list.isEmpty) return;
    final selectedId = ref.read(selectedCarIdProvider);
    if (selectedId == null) {
      ref.read(selectedCarIdProvider.notifier).set(list[_currentCarIndex].id);
      return;
    }
    final idx = list.indexWhere((c) => c.id == selectedId);
    if (idx < 0) return;
    final targetIndex = idx.clamp(0, list.length - 1);
    if (targetIndex == _currentCarIndex && _carPageController.hasClients) return;
    setState(() => _currentCarIndex = targetIndex);
    if (_carPageController.hasClients) {
      _carPageController.jumpToPage(targetIndex);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_carPageController.hasClients) {
          _carPageController.jumpToPage(targetIndex);
        }
      });
    }
  }

  @override
  void dispose() {
    _carPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final carsAsync = ref.watch(carsProvider);
    final carsList = carsAsync.valueOrNull ?? [];
    if (carsList.isNotEmpty) {
      ref.watch(maintenanceRemindersProvider);
      final orders = ref.watch(ordersProvider).valueOrNull ?? [];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(maintenanceRemindersProvider.notifier).syncFromOrders(orders, carsList);
      });
    }
    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: carsAsync.when(
          data: (_) => CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildCarSection()),
              if (_remindersOnboardingCarId != null)
                SliverToBoxAdapter(child: _buildRemindersOnboardingBanner()),
              SliverToBoxAdapter(child: _buildStats()),
              if (currentCar.reminders.isNotEmpty)
                SliverToBoxAdapter(child: _buildReminders()),
              if (cars.isNotEmpty)
                SliverToBoxAdapter(
                  child: GarageMaintenanceRecommendationsBlock(car: currentCar),
                ),
              SliverToBoxAdapter(child: _buildRecentOrders()),
              if (cars.isNotEmpty) SliverToBoxAdapter(child: _buildMaintenanceToBlock()),
              if (currentCar.reminders.any((r) => r.status != ReminderStatus.ok))
                SliverToBoxAdapter(child: _buildRecommendedServices()),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
          loading: () => Center(child: CircularProgressIndicator(color: context.palette.primary)),
          error: (_, __) => Center(child: Text(l10n.errorLoading, style: TextStyle(color: context.palette.error))),
        ),
      ),
    );
  }

  void _showGarageCarsSheet() {
    showGarageCarsManagementSheet(context, ref, onAddCar: _openAddCar);
  }

  Widget _buildHeader() {
    final l10n = L10nScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppDesignSystem.pagePaddingH, 12, AppDesignSystem.pagePaddingH, 0),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showGarageCarsSheet,
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 56,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.directions_car_rounded, color: context.palette.textPrimary, size: 24),
                          SizedBox(width: 12),
                          Text(l10n.garageScreenTitle, style: AppTextStyles.screenTitle(context.palette)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _HeaderButton(
              icon: Icons.notifications_outlined,
              badgeCount: ref.watch(unreadNotificationCountProvider).whenOrNull(data: (c) => c) ?? 0,
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => NotificationsScreen(initialCarId: ref.read(selectedCarIdProvider)))),
            ),
            SizedBox(width: 8),
            _HeaderButton(
              icon: Icons.add_rounded,
              onTap: _openAddCar,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddCar() async {
    final newId = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const AddCarScreen()),
    );
    if (!mounted || newId == null || newId.isEmpty) return;
    await ref.read(selectedCarIdProvider.notifier).set(newId);
    if (!mounted) return;
    final seen = ref.read(garageMaintenanceOnboardingSeenProvider);
    if (!seen.contains(newId)) {
      setState(() => _remindersOnboardingCarId = newId);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final list = ref.read(carsProvider).valueOrNull ?? [];
      final idx = list.indexWhere((c) => c.id == newId);
      if (idx >= 0) {
        setState(() => _currentCarIndex = idx);
        if (_carPageController.hasClients) {
          _carPageController.jumpToPage(idx);
        }
      }
    });
  }

  Future<void> _openMaintenanceFromOnboardingBanner() async {
    final id = _remindersOnboardingCarId;
    if (id == null) return;
    await ref.read(garageMaintenanceOnboardingSeenProvider.notifier).markSeen(id);
    await ref.read(selectedCarIdProvider.notifier).set(id);
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MaintenanceRemindersScreen(initialCarId: id),
      ),
    );
    if (mounted) setState(() => _remindersOnboardingCarId = null);
  }

  Widget _buildRemindersOnboardingBanner() {
    final id = _remindersOnboardingCarId;
    if (id == null) return const SizedBox.shrink();
    final list = cars;
    Car? car;
    for (final c in list) {
      if (c.id == id) {
        car = c;
        break;
      }
    }
    if (car == null) return const SizedBox.shrink();
    final name = car.displayName;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppDesignSystem.pagePaddingH, 0, AppDesignSystem.pagePaddingH, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.palette.cardBg,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall),
          border: Border.all(color: context.palette.strokeGold.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notifications_active_outlined, color: context.palette.gold1, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Настроить напоминания о ТО?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.palette.textPrimary,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Для $name можно задать интервалы замены масла и других работ — удобно следить за обслуживанием.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: context.palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(Icons.close_rounded, size: 20, color: context.palette.textTertiary),
                  onPressed: () {
                    final cid = id;
                    ref.read(garageMaintenanceOnboardingSeenProvider.notifier).markSeen(cid);
                    setState(() => _remindersOnboardingCarId = null);
                  },
                  tooltip: 'Скрыть',
                ),
              ],
            ),
            SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ref.read(garageMaintenanceOnboardingSeenProvider.notifier).markSeen(id);
                      setState(() => _remindersOnboardingCarId = null);
                    },
                    child: Text('Позже'),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _openMaintenanceFromOnboardingBanner,
                    child: Text('Настроить'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarSection() {
    if (cars.isEmpty) {
      return EmptyState(
        icon: '🚗',
        title: 'Добавьте ваш первый автомобиль',
        subtitle: 'чтобы начать работу',
        buttonText: '+ Добавить авто',
        onButton: _openAddCar,
      );
    }
    final selectedId = ref.watch(selectedCarIdProvider);
    if (selectedId != null) {
      final idx = cars.indexWhere((c) => c.id == selectedId);
      if (idx >= 0) {
        final targetIndex = idx.clamp(0, cars.length - 1);
        final pageNow = _carPageController.hasClients ? (_carPageController.page?.round() ?? _currentCarIndex) : _currentCarIndex;
        if (targetIndex != pageNow || targetIndex != _currentCarIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _currentCarIndex = targetIndex);
            if (_carPageController.hasClients) {
              _carPageController.jumpToPage(targetIndex);
            }
          });
        }
      }
    }
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _carPageController,
            physics: const BouncingScrollPhysics(),
            itemCount: cars.length,
            onPageChanged: (i) {
              setState(() => _currentCarIndex = i);
              if (i < cars.length) {
                ref.read(selectedCarIdProvider.notifier).set(cars[i].id);
              }
            },
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.pagePaddingH),
              child: CarCard(
                car: cars[i],
                unreadNotificationsCount: ref.watch(unreadByCarProvider).whenOrNull(data: (m) => m[cars[i].id] ?? 0) ?? 0,
                onFixReferenceTap: cars[i].hasManualReferencePending
                    ? () => Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => AddCarScreen(editCarId: cars[i].id),
                          ),
                        )
                    : null,
                onCardTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CarDetailScreen(carId: cars[i].id),
                  ),
                ),
                onImageTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CarPhotoDetailScreen(carId: cars[i].id),
                  ),
                ),
                onMileageTap: () => MileageUpdateSheet.show(
                  context,
                  cars[i],
                  (newKm) async {
                    final car = cars[i];
                    final ok = await ref.read(carsProvider.notifier).updateMileage(car.id, newKm);
                    if (!mounted || !ok) return;
                  },
                ),
              ),
            ),
          ),
        ),
        if (cars.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(cars.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _currentCarIndex ? 8 : 6,
                height: i == _currentCarIndex ? 8 : 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _currentCarIndex ? context.palette.gold1 : context.palette.textMuted,
                ),
              )),
            ),
          ),
      ],
    );
  }

  Widget _buildStats() {
    final last = lastOrder;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppDesignSystem.pagePaddingH, AppDesignSystem.blockSpacing, AppDesignSystem.pagePaddingH, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StatBlock(
              value: '${_ordersForFilter.length}',
              label: 'всего\nопераций',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AllOrdersScreen())),
            ),
            SizedBox(width: 10),
            StatBlock(value: Formatters.money(monthExpenses), label: 'за\nмесяц'),
            SizedBox(width: 10),
            StatBlock(
              value: last != null ? last.status.shortLabel : '—',
              // Номер заказа в подписи, без отдельной строки — высота как у блоков 1–2.
              label: last != null ? 'последний\nзаказ · #${last.orderNumber}' : 'последний\nзаказ',
              dotColor: last?.status.color,
              onTap: last != null ? () => pushCupertino(context, OrderDetailScreen(order: last)) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminders() {
    final l10n = L10nScope.of(context);
    final reminders = currentCar.reminders.where((r) => !r.isDismissed).toList()
      ..sort((a, b) => a.status.index.compareTo(b.status.index));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l10n.maintenanceRecommendations),
        ...reminders.map((r) => Padding(
          padding: const EdgeInsets.fromLTRB(AppDesignSystem.pagePaddingH, 0, AppDesignSystem.pagePaddingH, 10),
          child: ReminderCard(reminder: r),
        )),
      ],
    );
  }

  Widget _buildRecentOrders() {
    final l10n = L10nScope.of(context);
    final orders = recentOrders.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: l10n.lastActivity,
          compact: true,
          actionText: l10n.showAllArrow,
          onAction: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AllOrdersScreen())),
        ),
        if (orders.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.pagePaddingH),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                children: [
                  Icon(Icons.receipt_long_rounded, size: 20, color: context.palette.textTertiary),
                  SizedBox(width: 10),
                  Text(
                    l10n.noOrdersForThisCar,
                    style: TextStyle(
                      color: context.palette.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...orders.map((o) => Padding(
            padding: const EdgeInsets.fromLTRB(AppDesignSystem.pagePaddingH, 0, AppDesignSystem.pagePaddingH, 12),
            child: OrderCard(
              order: o,
              car: cars.firstWhere((c) => c.id == o.carId, orElse: () => cars.first),
              onReturnFromDetail: () => ref.read(ordersProvider.notifier).loadOrders(),
            ),
          )),
      ],
    );
  }

  /// Напоминания о ТО (интервалы из настроек): под «Последняя активность».
  Widget _buildMaintenanceToBlock() {
    final types = ref.watch(availableMaintenanceTypesProvider);
    return Padding(
      padding: const EdgeInsets.only(top: AppDesignSystem.blockSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Напоминания о ТО',
            compact: true,
            actionText: 'Все →',
            onAction: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => MaintenanceRemindersScreen(initialCarId: currentCar.id),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.pagePaddingH),
            child: CarMaintenanceRemindersSection(
              car: currentCar,
              availableTypes: types,
            ),
          ),
        ],
      ),
    );
  }

  /// Закреплённые точки: при включённой настройке «Сортировать по машине» — только подходящие под выбранное авто.
  List<STO> get _recommendedSTOs {
    final list = List<STO>.from(ref.watch(favoriteSTOsListProvider).valueOrNull ?? []);
    final filterByCar = ref.watch(filterByCarSettingProvider);
    final selectedId = ref.watch(selectedCarIdProvider);
    if (!filterByCar || selectedId == null) return list;
    final cars = ref.read(carsProvider).valueOrNull ?? [];
    Car? car;
    try {
      car = cars.firstWhere((c) => c.id == selectedId);
    } catch (_) {
      return list;
    }
    final brand = car.brand;
    return list.where((s) => stoMatchesCarBrand(s.specializations, brand)).toList();
  }

  Widget _buildRecommendedServices() {
    final recommended = _recommendedSTOs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Рекомендуемые сервисы'),
        SizedBox(
          height: 196,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.pagePaddingH),
            itemCount: recommended.length,
            separatorBuilder: (_, __) => SizedBox(width: 12),
            itemBuilder: (_, i) {
              final sto = recommended[i];
              return GestureDetector(
                onTap: () => pushStoDetailScreen(context, STODetailScreen(sto: sto)),
                child: Container(
                  width: 160,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1A191E), Color(0xFF111115)],
                    ),
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall),
                    border: Border.all(color: context.palette.strokeGold.withValues(alpha: 0.14)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.palette.strokeSoft),
                        ),
                        child: Center(
                          child: Text(sto.name[0], style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700, color: context.palette.gold1,
                          )),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        sto.name,
                        style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: context.palette.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star_rounded, size: 14, color: context.palette.gold1),
                          SizedBox(width: 2),
                          Text(Formatters.rating(sto.rating), style: TextStyle(
                            fontSize: 14, color: context.palette.textPrimary)),
                        ],
                      ),
                      if (sto.distanceKm != null) ...[
                        SizedBox(height: 2),
                        Text(Formatters.distance(sto.distanceKm!), style: TextStyle(
                          fontSize: 12, color: context.palette.textSecondary)),
                      ],
                      const Spacer(),
                      Text('Записаться →', style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500, color: context.palette.gold1,
                      )),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final int badgeCount;
  final VoidCallback onTap;
  const _HeaderButton({required this.icon, this.badgeCount = 0, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: context.palette.bgCard,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall),
          border: Border.all(color: context.palette.strokeSoft),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 22, color: context.palette.textPrimary),
            if (badgeCount > 0)
              Positioned(
                right: 6, top: 6,
                child: Container(
                  width: 16, height: 16,
                  decoration: BoxDecoration(color: context.palette.error, shape: BoxShape.circle),
                  child: Center(
                    child: Text('$badgeCount', style: TextStyle(
                      color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600,
                    )),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
