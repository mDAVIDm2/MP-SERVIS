import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/theme/desktop_design_system.dart';
import '../screens/brands_settings_screen.dart';
import '../screens/message_templates_screen.dart';
import '../screens/notifications_settings_screen.dart';
import '../screens/services_settings_screen.dart';
import '../screens/slots_settings_screen.dart';

/// Вкладка «Бизнес» на desktop: сетка карточек разделов вместо плоского списка.
class SettingsBusinessDesktopBody extends ConsumerWidget {
  const SettingsBusinessDesktopBody({super.key, required this.onDangerClearOrders});

  final Future<void> Function(BuildContext context, WidgetRef ref) onDangerClearOrders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: AppColorsDesktop.primary,
      onRefresh: () async {
        final orgId = ref.read(authProvider).user?.organizationId;
        await ref.read(settingsRepositoryProvider.notifier).load(orgId);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth > 960 ? 960.0 : constraints.maxWidth;
          final pad = DesktopDesignSystem.pagePadding;
          return ListView(
            padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: LayoutBuilder(
                    builder: (context, inner) {
                      final w = inner.maxWidth;
                      final twoCol = w >= 640;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      _IntroHero(),
                      const SizedBox(height: 24),
                      Text('Разделы', style: DesktopDesignSystem.sectionTitle),
                      const SizedBox(height: 4),
                      Text(
                        'Настройте услуги, марки, расписание и коммуникации с клиентами.',
                        style: DesktopDesignSystem.bodySecondary,
                      ),
                      const SizedBox(height: 20),
                      _SettingsCardGrid(
                        twoColumns: twoCol,
                        contentWidth: w,
                        children: [
                          _SettingsHubCardData(
                            icon: Icons.build_circle_outlined,
                            title: 'Услуги и цены',
                            subtitle: 'Единый справочник AutoHub, свои позиции, цены и длительность.',
                            accent: AppColorsDesktop.primary,
                            badge: 'Справочник',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ServicesSettingsScreen()),
                            ),
                          ),
                          _SettingsHubCardData(
                            icon: Icons.directions_car_outlined,
                            title: 'Специализация по маркам',
                            subtitle: 'По каким брендам вы принимаете авто — для фильтров и заявок.',
                            accent: const Color(0xFF0D9488),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const BrandsSettingsScreen()),
                            ),
                          ),
                          _SettingsHubCardData(
                            icon: Icons.schedule_rounded,
                            title: 'Слоты и подтверждение',
                            subtitle: 'Рабочий день, шаг сетки и время на подтверждение записи.',
                            accent: const Color(0xFF7C3AED),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SlotsSettingsScreen()),
                            ),
                          ),
                          _SettingsHubCardData(
                            icon: Icons.notifications_outlined,
                            title: 'Уведомления',
                            subtitle: 'Push по новым заявкам, чату, согласованиям и напоминаниям.',
                            accent: const Color(0xFFEA580C),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const NotificationsSettingsScreen()),
                            ),
                          ),
                          _SettingsHubCardData(
                            icon: Icons.message_outlined,
                            title: 'Шаблоны сообщений',
                            subtitle: 'Готовые ответы для чата с клиентами.',
                            accent: const Color(0xFF2563EB),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const MessageTemplatesScreen()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      _DangerZone(onClearOrders: () => onDangerClearOrders(context, ref)),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _IntroHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesktopDesignSystem.cardPaddingLarge + 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColorsDesktop.primary.withValues(alpha: 0.08),
            AppColorsDesktop.surface,
            AppColorsDesktop.nestedBg.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCardLarge),
        border: Border.all(color: AppColorsDesktop.borderLight),
        boxShadow: DesktopDesignSystem.shadowCard,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColorsDesktop.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.storefront_outlined, size: 32, color: AppColorsDesktop.primary),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Бизнес-профиль', style: DesktopDesignSystem.pageTitle),
                const SizedBox(height: 8),
                Text(
                  'Все параметры ниже синхронизируются с сервером и используются в календаре, заявках и чатах.',
                  style: DesktopDesignSystem.bodySecondary.copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsHubCardData {
  const _SettingsHubCardData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    this.badge,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;
  final String? badge;
}

class _SettingsCardGrid extends StatelessWidget {
  const _SettingsCardGrid({
    required this.twoColumns,
    required this.contentWidth,
    required this.children,
  });

  final bool twoColumns;
  final double contentWidth;
  final List<_SettingsHubCardData> children;

  @override
  Widget build(BuildContext context) {
    if (!twoColumns) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _SettingsHubCard(data: children[i]),
          ],
        ],
      );
    }
    final gap = 16.0;
    final cardW = (contentWidth - gap) / 2;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: children
          .map((d) => SizedBox(width: cardW, child: _SettingsHubCard(data: d)))
          .toList(),
    );
  }
}

class _SettingsHubCard extends StatefulWidget {
  const _SettingsHubCard({required this.data});
  final _SettingsHubCardData data;

  @override
  State<_SettingsHubCard> createState() => _SettingsHubCardState();
}

class _SettingsHubCardState extends State<_SettingsHubCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: d.onTap,
          borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(DesktopDesignSystem.cardPaddingLarge),
            decoration: BoxDecoration(
              color: AppColorsDesktop.surface,
              borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
              border: Border.all(
                color: _hover ? d.accent.withValues(alpha: 0.35) : AppColorsDesktop.border,
              ),
              boxShadow: _hover ? DesktopDesignSystem.shadowCardHover : DesktopDesignSystem.shadowCard,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: d.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(d.icon, color: d.accent, size: 22),
                    ),
                    const Spacer(),
                    if (d.badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColorsDesktop.nestedBg,
                          borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusBadge),
                          border: Border.all(color: AppColorsDesktop.borderLight),
                        ),
                        child: Text(
                          d.badge!,
                          style: DesktopDesignSystem.meta.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColorsDesktop.textSecondary,
                          ),
                        ),
                      ),
                    Icon(Icons.chevron_right_rounded, color: AppColorsDesktop.textTertiary),
                  ],
                ),
                const SizedBox(height: 14),
                Text(d.title, style: DesktopDesignSystem.sectionTitle),
                const SizedBox(height: 6),
                Text(d.subtitle, style: DesktopDesignSystem.bodySecondary.copyWith(height: 1.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DangerZone extends StatelessWidget {
  const _DangerZone({required this.onClearOrders});
  final VoidCallback onClearOrders;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesktopDesignSystem.cardPaddingLarge),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error.withValues(alpha: 0.9), size: 22),
              const SizedBox(width: 10),
              Text('Опасная зона', style: DesktopDesignSystem.sectionTitle.copyWith(color: AppColors.error)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Очистка заказов необратима. Используйте только на тестовых стендах или по согласованию.',
            style: DesktopDesignSystem.bodySecondary,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onClearOrders,
            icon: const Icon(Icons.delete_sweep_rounded, size: 20),
            label: const Text('Очистить все заказы'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
