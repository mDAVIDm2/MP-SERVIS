import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/theme/desktop_design_system.dart';

/// Десктоп: уведомления — карточки с переключателями.
class NotificationsSettingsDesktopScreen extends ConsumerWidget {
  const NotificationsSettingsDesktopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(settingsRepositoryProvider).notificationSettings;
    final repo = ref.read(settingsRepositoryProvider.notifier);

    return Scaffold(
      backgroundColor: AppColorsDesktop.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColorsDesktop.surface,
        foregroundColor: AppColorsDesktop.textPrimary,
        title: const Text('Уведомления'),
      ),
      body: RefreshIndicator(
        color: AppColorsDesktop.primary,
        onRefresh: () async {
          final orgId = ref.read(authProvider).user?.organizationId;
          await ref.read(settingsRepositoryProvider.notifier).load(orgId);
        },
        child: ListView(
          padding: const EdgeInsets.all(DesktopDesignSystem.pagePadding),
          children: [
            Container(
              padding: const EdgeInsets.all(DesktopDesignSystem.cardPaddingLarge),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColorsDesktop.surface,
                borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCardLarge),
                border: Border.all(color: AppColorsDesktop.borderLight),
                boxShadow: DesktopDesignSystem.shadowCard,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notifications_active_outlined, color: AppColorsDesktop.primary, size: 26),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Push на устройство мастера и администратора', style: DesktopDesignSystem.sectionTitle),
                        const SizedBox(height: 6),
                        Text(
                          'Отключите типы, от которых не хотите отвлекаться. Критичные статусы заказов в приложении останутся доступны.',
                          style: DesktopDesignSystem.bodySecondary.copyWith(height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _NotifyTile(
              icon: Icons.add_task_rounded,
              title: 'Новая заявка',
              subtitle: 'Клиент создал запись на сервис',
              value: n.newOrder,
              onChanged: (v) => repo.updateNotifications(n.copyWith(newOrder: v)),
            ),
            const SizedBox(height: 12),
            _NotifyTile(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Сообщение в чате',
              subtitle: 'Новое сообщение от клиента по заказу',
              value: n.newMessage,
              onChanged: (v) => repo.updateNotifications(n.copyWith(newMessage: v)),
            ),
            const SizedBox(height: 12),
            _NotifyTile(
              icon: Icons.rule_folder_outlined,
              title: 'Ответ по согласованию',
              subtitle: 'Клиент ответил на запрос дополнительных работ',
              value: n.approvalResponse,
              onChanged: (v) => repo.updateNotifications(n.copyWith(approvalResponse: v)),
            ),
            const SizedBox(height: 12),
            _NotifyTile(
              icon: Icons.event_available_outlined,
              title: 'Напоминание о записи',
              subtitle: 'За день или в день визита',
              value: n.orderReminder,
              onChanged: (v) => repo.updateNotifications(n.copyWith(orderReminder: v)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifyTile extends StatelessWidget {
  const _NotifyTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColorsDesktop.surface,
        borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
        border: Border.all(color: AppColorsDesktop.border),
        boxShadow: DesktopDesignSystem.shadowCard,
      ),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColorsDesktop.primary,
        activeTrackColor: AppColorsDesktop.primary.withValues(alpha: 0.35),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        secondary: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColorsDesktop.nestedBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColorsDesktop.textSecondary, size: 22),
        ),
        title: Text(title, style: DesktopDesignSystem.body.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle, style: DesktopDesignSystem.bodySecondary),
        ),
      ),
    );
  }
}
