import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/order_repository.dart';

/// Способ оплаты при закрытии заказа (в Business: наличные и карта).
enum PaymentMethod {
  cash('Наличные'),
  card('Карта'),
  // transfer('Перевод'), // Онлайн-оплата пока скрыта
  ;

  const PaymentMethod(this.label);
  final String label;
}

/// Экран оплаты по заказу: сумма, способ оплаты, подтверждение.
class OrderPaymentScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderPaymentScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderPaymentScreen> createState() => _OrderPaymentScreenState();
}

class _OrderPaymentScreenState extends ConsumerState<OrderPaymentScreen> {
  PaymentMethod _method = PaymentMethod.cash;

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderByIdProvider(widget.orderId));
    final canSeePrices = ref.watch(authProvider).user?.role.canSeePrices ?? true;

    if (order == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Оплата')),
        body: const Center(
          child: Text('Заказ не найден', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    final totalKopecks = order.totalKopecks;
    final showAmount = canSeePrices && totalKopecks > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Оплата'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            order.orderNumber,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            order.carInfo,
            style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 24),
          const Text(
            'Сумма к оплате',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            showAmount ? formatMoney(totalKopecks) : '—',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          if (!showAmount)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Цены скрыты для вашей роли',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ),
          const SizedBox(height: 32),
          const Text(
            'Способ оплаты',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          ...PaymentMethod.values.map((m) => RadioListTile<PaymentMethod>(
                value: m,
                groupValue: _method,
                onChanged: (v) => setState(() => _method = v!),
                title: Text(m.label, style: const TextStyle(color: AppColors.textPrimary)),
                activeColor: AppColors.primary,
              )),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () async => await _confirmPayment(context, ref, order),
            child: const Text('Оплата получена / Заказ выдан'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmPayment(BuildContext context, WidgetRef ref, Order order) async {
    final result = await ref.read(orderRepositoryProvider.notifier).setOrderStatus(order.id, OrderStatus.done);
    if (!context.mounted) return;
    if (result.errorOrNull == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заказ закрыт'),
          backgroundColor: AppColors.cardBg,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorOrNull!.message),
          backgroundColor: AppColors.cardBg,
        ),
      );
    }
  }
}
