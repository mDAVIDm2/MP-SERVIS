import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/config/platform_utils.dart';
import '../../../../core/repositories/chat_repository.dart';
import '../../../../core/repositories/organization_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/theme/desktop_light_theme.dart';
import '../../../../shared/models/organization_model.dart';
import '../../../../shared/models/organization_subscription_usage.dart';
import '../../../chats/presentation/screens/chat_detail_screen.dart';

/// Тариф организации: план, лимиты и фактическое использование (из `subscription_usage` API).
class SubscriptionTariffScreen extends ConsumerWidget {
  const SubscriptionTariffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desk = isDesktopPlatform;
    final orgAsync = ref.watch(organizationRepositoryProvider);
    final org = orgAsync.valueOrNull;
    final usage = org?.subscriptionUsage;

    Future<void> onRefresh() async {
      final orgId = ref.read(authProvider).user?.effectiveOrganizationId;
      await ref.read(organizationRepositoryProvider.notifier).load(orgId);
    }

    final body = LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          color: desk ? AppColorsDesktop.primary : AppColors.primary,
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: EdgeInsets.fromLTRB(desk ? 28 : 16, desk ? 20 : 16, desk ? 28 : 16, desk ? 36 : 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: desk ? 880 : double.infinity),
                    child: _TariffContent(
                      desk: desk,
                      orgAsync: orgAsync,
                      usage: usage,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (desk) {
      return themeDesktopLight(
        child: Scaffold(
          backgroundColor: AppColorsDesktop.background,
          appBar: AppBar(
            title: const Text('Тариф'),
            backgroundColor: AppColorsDesktop.surface,
            foregroundColor: AppColorsDesktop.textPrimary,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),
          body: body,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Тариф'),
      ),
      body: body,
    );
  }
}

class _TariffContent extends ConsumerWidget {
  const _TariffContent({
    required this.desk,
    required this.orgAsync,
    required this.usage,
  });

  final bool desk;
  final AsyncValue<OrganizationInfo> orgAsync;
  final OrganizationSubscriptionUsage? usage;

  static String _usageLine(int used, int? max) {
    if (max == null) return '$used (без лимита)';
    return '$used из $max';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tp = desk ? AppColorsDesktop.textPrimary : AppColors.textPrimary;
    final ts = desk ? AppColorsDesktop.textSecondary : AppColors.textSecondary;
    final tt = desk ? AppColorsDesktop.textTertiary : AppColors.textTertiary;
    final primary = desk ? AppColorsDesktop.primary : AppColors.primary;
    final err = desk ? AppColorsDesktop.error : AppColors.error;
    final cardBg = desk ? AppColorsDesktop.surface : AppColors.cardBg;
    final border = desk ? AppColorsDesktop.border : AppColors.border;

    final org = orgAsync.valueOrNull;
    final u = usage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (orgAsync.isLoading && org == null)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(color: primary),
            ),
          )
        else if (u == null) ...[
          Text(
            'Данные тарифа ещё не загружены',
            style: TextStyle(
              fontSize: desk ? 18 : 16,
              fontWeight: FontWeight.w600,
              color: tp,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Потяните экран вниз для обновления или откройте экран позже — после ответа сервера здесь появятся план и лимиты.',
            style: TextStyle(fontSize: desk ? 14 : 14, height: 1.45, color: ts),
          ),
        ] else ...[
          if (desk)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    OrganizationSubscriptionUsage.planTitleRu(u.planKey),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: tp,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        u.subscriptionActive ? Icons.check_circle_outline_rounded : Icons.pause_circle_outline_rounded,
                        size: 18,
                        color: u.subscriptionActive ? primary : err,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          u.subscriptionActive
                              ? 'Подписка активна'
                              : 'Подписка неактивна — часть функций может быть ограничена',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.35,
                            color: u.subscriptionActive ? ts : err,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (u.subscriptionStatus != null && u.subscriptionStatus!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Статус: ${u.subscriptionStatus}', style: TextStyle(fontSize: 13, color: ts)),
                  ],
                  if (u.subscriptionEndDate != null && u.subscriptionEndDate!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Действует до: ${u.subscriptionEndDate}', style: TextStyle(fontSize: 13, color: ts)),
                  ],
                ],
              ),
            )
          else ...[
            Text(
              OrganizationSubscriptionUsage.planTitleRu(u.planKey),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: tp,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              u.subscriptionActive
                  ? 'Подписка активна'
                  : 'Подписка неактивна — часть функций может быть ограничена',
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: u.subscriptionActive ? ts : err,
              ),
            ),
            if (u.subscriptionStatus != null && u.subscriptionStatus!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Статус: ${u.subscriptionStatus}', style: TextStyle(fontSize: 13, color: ts)),
            ],
            if (u.subscriptionEndDate != null && u.subscriptionEndDate!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Действует до: ${u.subscriptionEndDate}', style: TextStyle(fontSize: 13, color: ts)),
            ],
          ],
          SizedBox(height: desk ? 24 : 20),
          if (desk)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _DesktopUsageCard(
                    title: 'Использование',
                    borderColor: border,
                    surface: cardBg,
                    textPrimary: tp,
                    textSecondary: ts,
                    children: [
                      _UsageRow(
                        desk: desk,
                        title: 'Подтверждённые заказы в этом месяце',
                        value: _usageLine(u.confirmedOrdersThisMonth, u.limits.maxConfirmedOrdersPerMonth),
                        textPrimary: tp,
                        textSecondary: ts,
                        textTertiary: tt,
                      ),
                      _UsageRow(
                        desk: desk,
                        title: 'Активные сотрудники',
                        value: _usageLine(u.activeStaff, u.limits.maxActiveStaff),
                        textPrimary: tp,
                        textSecondary: ts,
                        textTertiary: tt,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _DesktopUsageCard(
                    title: 'Лимиты тарифа',
                    borderColor: border,
                    surface: cardBg,
                    textPrimary: tp,
                    textSecondary: ts,
                    children: [
                      _UsageRow(
                        desk: desk,
                        title: 'Фото в одном сообщении чата',
                        value: u.limits.describeChatPhotoLimit(),
                        hint:
                            'Если отправка фото не проходит, проверьте сеть и это ограничение. При необходимости обратитесь в поддержку для смены тарифа.',
                        textPrimary: tp,
                        textSecondary: ts,
                        textTertiary: tt,
                      ),
                      _UsageRow(
                        desk: desk,
                        title: 'Вложения к заказу (медиа)',
                        value: u.limits.describeOrderMediaLimit(),
                        textPrimary: tp,
                        textSecondary: ts,
                        textTertiary: tt,
                      ),
                      _UsageRow(
                        desk: desk,
                        title: 'Заказов в месяц (подтверждённых)',
                        value: u.limits.describeOrdersMonthLimit(),
                        textPrimary: tp,
                        textSecondary: ts,
                        textTertiary: tt,
                      ),
                      _UsageRow(
                        desk: desk,
                        title: 'Сотрудников',
                        value: u.limits.describeStaffLimit(),
                        textPrimary: tp,
                        textSecondary: ts,
                        textTertiary: tt,
                      ),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            Text(
              'Использование',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: tp,
              ),
            ),
            const SizedBox(height: 8),
            _UsageRow(
              desk: desk,
              title: 'Подтверждённые заказы в этом месяце',
              value: _usageLine(u.confirmedOrdersThisMonth, u.limits.maxConfirmedOrdersPerMonth),
              textPrimary: tp,
              textSecondary: ts,
              textTertiary: tt,
            ),
            _UsageRow(
              desk: desk,
              title: 'Активные сотрудники',
              value: _usageLine(u.activeStaff, u.limits.maxActiveStaff),
              textPrimary: tp,
              textSecondary: ts,
              textTertiary: tt,
            ),
            const SizedBox(height: 20),
            Text(
              'Лимиты тарифа',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: tp,
              ),
            ),
            const SizedBox(height: 8),
            _UsageRow(
              desk: desk,
              title: 'Фото в одном сообщении чата',
              value: u.limits.describeChatPhotoLimit(),
              hint:
                  'Если отправка фото не проходит, проверьте сеть и это ограничение. При необходимости обратитесь в поддержку для смены тарифа.',
              textPrimary: tp,
              textSecondary: ts,
              textTertiary: tt,
            ),
            _UsageRow(
              desk: desk,
              title: 'Вложения к заказу (медиа)',
              value: u.limits.describeOrderMediaLimit(),
              textPrimary: tp,
              textSecondary: ts,
              textTertiary: tt,
            ),
            _UsageRow(
              desk: desk,
              title: 'Заказов в месяц (подтверждённых)',
              value: u.limits.describeOrdersMonthLimit(),
              textPrimary: tp,
              textSecondary: ts,
              textTertiary: tt,
            ),
            _UsageRow(
              desk: desk,
              title: 'Сотрудников',
              value: u.limits.describeStaffLimit(),
              textPrimary: tp,
              textSecondary: ts,
              textTertiary: tt,
            ),
          ],
          SizedBox(height: desk ? 16 : 12),
          Text(
            'Числа выше — по текущему плану. Если в интерфейсе указано иначе, ориентируйтесь на подсказки при ошибках отправки.',
            style: TextStyle(fontSize: 13, height: 1.45, color: tt),
          ),
        ],
        SizedBox(height: desk ? 32 : 28),
        FilledButton.icon(
          onPressed: () async {
            final r = await ref.read(chatRepositoryProvider.notifier).openSupportChat();
            if (!context.mounted) return;
            final preview = r.dataOrNull;
            if (preview != null) {
              await ensureChatDataLoaded(ref, preview.id, refValid: () => context.mounted);
              if (!context.mounted) return;
              await Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => ChatDetailScreen(chatId: preview.id)),
              );
            } else {
              final errMsg = r.errorOrNull;
              if (errMsg != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errMsg.message)));
              }
            }
          },
          icon: const Icon(Icons.rocket_launch_outlined),
          label: const Text('Улучшить тариф'),
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: desk ? 16 : 14),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Смена тарифа и лимитов оформляется через поддержку MP-Servis — нажмите кнопку выше, чтобы открыть чат.',
          style: TextStyle(fontSize: 13, height: 1.45, color: ts),
        ),
      ],
    );
  }
}

class _DesktopUsageCard extends StatelessWidget {
  const _DesktopUsageCard({
    required this.title,
    required this.children,
    required this.borderColor,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
  });

  final String title;
  final List<Widget> children;
  final Color borderColor;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({
    required this.desk,
    required this.title,
    required this.value,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    this.hint,
  });

  final bool desk;
  final String title;
  final String value;
  final String? hint;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: desk ? 14 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: desk ? 13 : 14,
              fontWeight: FontWeight.w500,
              color: textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: desk ? 15 : 14,
              fontWeight: desk ? FontWeight.w600 : FontWeight.w500,
              color: desk ? textPrimary : textSecondary,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(
              hint!,
              style: TextStyle(fontSize: 12, height: 1.4, color: textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}
