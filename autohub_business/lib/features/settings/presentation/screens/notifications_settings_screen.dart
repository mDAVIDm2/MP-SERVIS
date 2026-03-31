import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/platform_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/repositories/settings_repository.dart';
import 'notifications_settings_desktop_screen.dart';

class NotificationsSettingsScreen extends ConsumerWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isDesktopPlatform) {
      return const NotificationsSettingsDesktopScreen();
    }
    final n = ref.watch(settingsRepositoryProvider).notificationSettings;
    final repo = ref.read(settingsRepositoryProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Уведомления'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Новая заявка'),
            subtitle: const Text('Когда клиент создаёт запись'),
            value: n.newOrder,
            onChanged: (v) => repo.updateNotifications(n.copyWith(newOrder: v)),
          ),
          SwitchListTile(
            title: const Text('Сообщение в чате'),
            subtitle: const Text('Новое сообщение от клиента'),
            value: n.newMessage,
            onChanged: (v) => repo.updateNotifications(n.copyWith(newMessage: v)),
          ),
          SwitchListTile(
            title: const Text('Ответ по согласованию'),
            subtitle: const Text('Клиент ответил на запрос доп. работ'),
            value: n.approvalResponse,
            onChanged: (v) => repo.updateNotifications(n.copyWith(approvalResponse: v)),
          ),
          SwitchListTile(
            title: const Text('Напоминание о записи'),
            subtitle: const Text('За день или в день визита'),
            value: n.orderReminder,
            onChanged: (v) => repo.updateNotifications(n.copyWith(orderReminder: v)),
          ),
        ],
      ),
    );
  }
}
