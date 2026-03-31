import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/api/internal_data_providers.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/constants/labels_ru.dart';
import '../../../core/theme/app_colors.dart';
import '../sections/section_scaffold.dart';

class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(subscriptionsProvider);
    return SectionScaffold(
      title: 'Подписки',
      child: async.when(
        data: (items) {
          if (items.isEmpty) {
            return _emptyCard();
          }
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final e = items[index];
              final orgName = e['organization_name'] as String? ?? 'Без названия';
              final startDate = e['start_date'] as String?;
              final endDate = e['end_date'] as String?;
              final isActive = e['is_active'] == true;
              final status = e['status'] as String? ?? 'active';
              final statusLabel = LabelsRu.subscriptionStatus(status);
              final orgId = e['organization_id'] as String? ?? '';
              final ov = e['limits_override'];
              final hasCustomLimits = ov is Map && ov.isNotEmpty;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: orgId.isNotEmpty ? () => context.go('/app/organizations/$orgId') : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive ? const Color(0xFF86EFAC).withValues(alpha: 0.5) : AppColors.border,
                    width: isActive ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: isActive,
                        onChanged: null,
                        activeColor: const Color(0xFF22C55E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  orgName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (hasCustomLimits) ...[
                                const SizedBox(width: 8),
                                Tooltip(
                                  message: 'Заданы индивидуальные лимиты в карточке организации',
                                  child: Icon(Icons.tune_rounded, size: 18, color: AppColors.textSecondary.withValues(alpha: 0.85)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _DateChip(
                                label: 'Начало',
                                value: _formatDate(startDate),
                              ),
                              const SizedBox(width: 12),
                              _DateChip(
                                label: 'Окончание',
                                value: _formatDate(endDate),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFFDCFCE7)
                            : status == 'expired'
                                ? const Color(0xFFFEE2E2)
                                : AppColors.border.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? const Color(0xFF166534)
                              : status == 'expired'
                                  ? AppColors.danger
                                  : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SubscriptionActions(ref: ref, organizationId: e['organization_id'] as String?, isActive: isActive),
                  ],
                ),
              ),
            ),
          );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Ошибка загрузки: $e', style: const TextStyle(color: AppColors.danger)),
          ),
        ),
      ),
    );
  }

  String _formatDate(String? v) {
    if (v == null || v.isEmpty) return '—';
    try {
      final d = DateTime.parse(v);
      return DateFormat('dd.MM.yyyy').format(d);
    } catch (_) {
      return v;
    }
  }

  Widget _emptyCard() => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.card_membership_rounded, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                const Text(
                  'Нет подписок',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      );
}

class _SubscriptionActions extends StatelessWidget {
  const _SubscriptionActions({required this.ref, required this.organizationId, required this.isActive});

  final WidgetRef ref;
  final String? organizationId;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    if (organizationId == null) return const SizedBox.shrink();
    return SizedBox(
      width: 140,
      child: isActive
          ? OutlinedButton(
              onPressed: () => _update(context, false),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Деактивировать'),
            )
          : FilledButton(
              onPressed: () => _update(context, true),
              child: const Text('Активировать'),
            ),
    );
  }

  Future<void> _update(BuildContext context, bool active) async {
    final ok = await ref.read(internalApiProvider).updateSubscription(organizationId!, isActive: active, status: active ? 'active' : 'deactivated');
    if (context.mounted) {
      ref.invalidate(subscriptionsProvider);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(active ? 'Подписка активирована' : 'Подписка деактивирована')),
        );
      }
    }
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}
