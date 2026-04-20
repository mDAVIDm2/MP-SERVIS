import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/repositories/order_repository.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../core/utils/formatters.dart';

/// Отдельный экран «Финансы» (не Панель): выручка, средний чек, экспорт.
class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(orderRepositoryProvider);
    final completed = orders.where((o) => o.status == OrderStatus.done || o.status == OrderStatus.completed).toList();
    final totalKopecks = completed.fold<int>(0, (s, o) => s + o.totalKopecks);
    final avgKopecks = completed.isEmpty ? 0 : totalKopecks ~/ completed.length;

    return Scaffold(
      backgroundColor: AppColorsDesktop.background,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Выручка (завершённые)',
                  value: formatMoney(totalKopecks),
                  icon: Icons.trending_up_rounded,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  title: 'Средний чек',
                  value: formatMoney(avgKopecks),
                  icon: Icons.receipt_long_rounded,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  title: 'Заказов завершено',
                  value: '${completed.length}',
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Экспорт CSV / XLSX'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColorsDesktop.primary,
              side: const BorderSide(color: AppColorsDesktop.border),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value, required this.icon});

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColorsDesktop.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColorsDesktop.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColorsDesktop.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColorsDesktop.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColorsDesktop.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
