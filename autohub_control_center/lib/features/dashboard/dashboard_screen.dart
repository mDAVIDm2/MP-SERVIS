import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/internal_data_providers.dart';
import '../../../core/theme/app_colors.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgAsync = ref.watch(organizationsProvider);
    final usersAsync = ref.watch(usersProvider);
    final ordersAsync = ref.watch(ordersProvider(const (limit: 1, offset: 0)));
    final auditAsync = ref.watch(auditProvider(const (limit: 1, offset: 0, from: null, to: null)));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Панель',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Добро пожаловать в MP-Servis Control Center. Выберите раздел для управления.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _SummaryCard(
                title: 'Организации',
                value: orgAsync.valueOrNull?.length.toString() ?? '…',
                icon: Icons.business_rounded,
                onTap: () => context.go('/app/organizations'),
              ),
              _SummaryCard(
                title: 'Пользователи',
                value: usersAsync.valueOrNull?.length.toString() ?? '…',
                icon: Icons.people_rounded,
                onTap: () => context.go('/app/users'),
              ),
              _SummaryCard(
                title: 'Заказы',
                value: ordersAsync.valueOrNull?['total']?.toString() ?? '…',
                icon: Icons.shopping_cart_rounded,
                onTap: () => context.go('/app/orders'),
              ),
              _SummaryCard(
                title: 'Аудит (записей)',
                value: auditAsync.valueOrNull?['total']?.toString() ?? '…',
                icon: Icons.history_rounded,
                onTap: () => context.go('/app/audit'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 180, maxWidth: 220),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
    if (onTap != null) {
      return Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: card));
    }
    return card;
  }
}
