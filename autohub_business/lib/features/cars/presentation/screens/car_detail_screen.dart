import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/theme/desktop_design_system.dart';
import '../../../../core/config/platform_utils.dart';
import '../../../../core/repositories/order_repository.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../shared/models/car_aggregate.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../core/utils/formatters.dart';
import '../../../orders/presentation/screens/order_detail_screen.dart';
import '../../../orders/presentation/widgets/order_detail_panel.dart';
import '../providers/cars_providers.dart';

class CarDetailScreen extends ConsumerWidget {
  const CarDetailScreen({
    super.key,
    required this.carId,
    required this.carInfo,
  });

  final String carId;
  final String carInfo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cars = ref.watch(carsFromOrdersProvider);
    CarView? car;
    for (final c in cars) {
      if (c.id == carId) { car = c; break; }
    }
    final canSeePrices = ref.watch(authProvider).user?.role.canSeePrices ?? true;

    if (car == null) {
      return Scaffold(
        backgroundColor: isDesktopPlatform ? AppColorsDesktop.background : AppColors.background,
        appBar: AppBar(
          title: Text(carInfo),
          backgroundColor: isDesktopPlatform ? null : AppColors.background,
          foregroundColor: isDesktopPlatform ? null : AppColors.textPrimary,
        ),
        body: Center(
          child: Text(
            'Данные об автомобиле не найдены',
            style: TextStyle(
              color: isDesktopPlatform ? AppColorsDesktop.textSecondary : AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    if (isDesktopPlatform) {
      return _buildDesktop(context, ref, car, canSeePrices);
    }
    return _buildMobile(context, ref, car, canSeePrices);
  }

  Widget _buildDesktop(BuildContext context, WidgetRef ref, CarView car, bool canSeePrices) {
    return Scaffold(
      backgroundColor: AppColorsDesktop.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(DesktopDesignSystem.pagePadding),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CarInfoCard(car: car, canSeePrices: canSeePrices, isDesktop: true),
                  const SizedBox(height: DesktopDesignSystem.blockSpacing),
                  _CarOrdersSection(
                    orders: car.orders,
                    canSeePrices: canSeePrices,
                    isDesktop: true,
                    onOrderTap: (order) => _openOrderDetail(context, ref, order),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobile(BuildContext context, WidgetRef ref, CarView car, bool canSeePrices) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(car.carInfo),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _CarInfoCard(car: car, canSeePrices: canSeePrices, isDesktop: false),
          const SizedBox(height: 24),
          _CarOrdersSection(
            orders: car.orders,
            canSeePrices: canSeePrices,
            isDesktop: false,
            onOrderTap: (order) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderDetailScreen(orderId: order.id),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openOrderDetail(BuildContext context, WidgetRef ref, Order order) {
    if (isDesktopPlatform) {
      showDialog<void>(
        context: context,
        barrierColor: Colors.black54,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Container(
            width: 520,
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 800),
            decoration: BoxDecoration(
              color: AppColorsDesktop.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColorsDesktop.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: Text(order.orderNumber),
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
                Expanded(
                  child: OrderDetailPanel(
                    orderId: order.id,
                    onClose: () => Navigator.pop(ctx),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(orderId: order.id),
        ),
      );
    }
  }
}

class _CarInfoCard extends StatelessWidget {
  const _CarInfoCard({required this.car, required this.canSeePrices, this.isDesktop = true});

  final CarView car;
  final bool canSeePrices;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final surface = isDesktop ? AppColorsDesktop.surface : AppColors.cardBg;
    final border = isDesktop ? AppColorsDesktop.border : AppColors.border;
    final primary = isDesktop ? AppColorsDesktop.primary : AppColors.primary;
    final textPrimary = isDesktop ? AppColorsDesktop.textPrimary : AppColors.textPrimary;
    final textSecondary = isDesktop ? AppColorsDesktop.textSecondary : AppColors.textSecondary;
    final textTertiary = isDesktop ? AppColorsDesktop.textTertiary : AppColors.textTertiary;
    final accentMoney = isDesktop ? AppColorsDesktop.accentMoney : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(DesktopDesignSystem.cardPadding),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
        border: Border.all(color: border),
        boxShadow: isDesktop ? DesktopDesignSystem.shadowCard : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: isDesktop ? 0.1 : 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.directions_car_rounded, color: primary, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      car.carInfo,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    if (car.licensePlate != null && car.licensePlate!.isNotEmpty)
                      _copyableLine(context, 'Гос. номер', car.licensePlate!, isDesktop),
                    if (car.vin != null && car.vin!.isNotEmpty)
                      _copyableLine(context, 'VIN', car.vin!, isDesktop),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(height: 1, color: border),
          const SizedBox(height: 16),
          _row('Владелец', car.clientName ?? '—', textSecondary, textPrimary),
          if (car.clientPhone != null && car.clientPhone!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _row('Телефон', car.clientPhone!, textSecondary, textPrimary),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => launchUrl(Uri(scheme: 'tel', path: car.clientPhone!.replaceAll(RegExp(r'[^\d+]'), ''))),
                icon: Icon(Icons.phone_rounded, size: 18, color: primary),
                label: Text('Позвонить', style: TextStyle(color: primary)),
              ),
            ),
          ],
          if (car.bodyType != null && car.bodyType!.isNotEmpty) _row('Тип кузова', car.bodyType!, textSecondary, textPrimary),
          if (car.color != null && car.color!.isNotEmpty) _row('Цвет', car.color!, textSecondary, textPrimary),
          if (car.mileage != null) _row('Пробег', '${car.mileage} км', textSecondary, textPrimary),
          if (car.engineType != null && car.engineType!.isNotEmpty) _row('Двигатель', car.engineType!, textSecondary, textPrimary),
          const SizedBox(height: 16),
          Divider(height: 1, color: border),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Всего заказов', style: TextStyle(color: textSecondary, fontSize: 14)),
              Text('${car.orderCount}', style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
            ],
          ),
          if (canSeePrices && car.totalKopecks > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Сумма обслуживаний', style: TextStyle(color: textSecondary, fontSize: 14)),
                Text(formatMoney(car.totalKopecks), style: TextStyle(fontWeight: FontWeight.w700, color: accentMoney)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color labelColor, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text('$label:', style: TextStyle(color: labelColor, fontSize: 13))),
          Expanded(child: Text(value, style: TextStyle(color: valueColor, fontSize: 14))),
        ],
      ),
    );
  }

  static Widget _copyableLine(BuildContext context, String label, String value, [bool isDesktop = true]) {
    final textSecondary = isDesktop ? AppColorsDesktop.textSecondary : AppColors.textSecondary;
    final textPrimary = isDesktop ? AppColorsDesktop.textPrimary : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('$label: ', style: TextStyle(color: textSecondary, fontSize: 14)),
          Expanded(child: Text(value, style: TextStyle(color: textPrimary, fontSize: 14))),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label скопирован'), duration: const Duration(seconds: 1), behavior: SnackBarBehavior.fixed),
              );
            },
            tooltip: 'Копировать',
            style: IconButton.styleFrom(foregroundColor: textSecondary, minimumSize: const Size(36, 36)),
          ),
        ],
      ),
    );
  }
}

class _CarOrdersSection extends StatelessWidget {
  const _CarOrdersSection({
    required this.orders,
    required this.canSeePrices,
    required this.onOrderTap,
    this.isDesktop = true,
  });

  final List<Order> orders;
  final bool canSeePrices;
  final void Function(Order order) onOrderTap;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final surface = isDesktop ? AppColorsDesktop.surface : AppColors.cardBg;
    final border = isDesktop ? AppColorsDesktop.border : AppColors.border;
    final textSecondary = isDesktop ? AppColorsDesktop.textSecondary : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(DesktopDesignSystem.cardPadding),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
        border: Border.all(color: border),
        boxShadow: isDesktop ? DesktopDesignSystem.shadowCard : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Заказы по этому автомобилю',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDesktop ? AppColorsDesktop.textPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (orders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Нет заказов',
                  style: TextStyle(color: textSecondary, fontSize: 14),
                ),
              ),
            )
          else
            ...orders.map((order) => _OrderTile(
                  order: order,
                  canSeePrices: canSeePrices,
                  isDesktop: isDesktop,
                  onTap: () => onOrderTap(order),
                )),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({
    required this.order,
    required this.canSeePrices,
    required this.onTap,
    this.isDesktop = true,
  });

  final Order order;
  final bool canSeePrices;
  final VoidCallback onTap;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDesktop ? AppColorsDesktop.textPrimary : AppColors.textPrimary;
    final textTertiary = isDesktop ? AppColorsDesktop.textTertiary : AppColors.textTertiary;
    final accentMoney = isDesktop ? AppColorsDesktop.accentMoney : AppColors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 40,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: order.status.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    order.orderNumber.replaceAll(RegExp(r'[^\d-]'), '').length > 4
                        ? '#${order.orderNumber.split('-').last}'
                        : order.orderNumber,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: order.status.color),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDateShort(order.effectiveDateTime),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.status.label,
                      style: TextStyle(fontSize: 12, color: order.status.color),
                    ),
                    if (order.masterName != null && order.masterName!.isNotEmpty)
                      Text(
                        'Мастер: ${order.masterName}',
                        style: TextStyle(fontSize: 11, color: textTertiary),
                      ),
                  ],
                ),
              ),
              if (canSeePrices && order.totalKopecks > 0)
                Text(
                  formatMoney(order.totalKopecks),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: accentMoney),
                ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
