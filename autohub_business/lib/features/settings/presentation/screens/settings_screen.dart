import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/config/platform_utils.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../core/repositories/order_repository.dart';
import '../../../../core/repositories/chat_repository.dart';
import '../widgets/desktop_settings_workspace.dart';
import 'services_settings_screen.dart';
import 'brands_settings_screen.dart';
import 'slots_settings_screen.dart';
import 'notifications_settings_screen.dart';
import 'message_templates_screen.dart';

/// Главный экран настроек: на desktop — организация (персонал, клиенты, авто, сервис); на мобиле — только бизнес-настройки.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmClearAllOrders(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Очистить все заказы?'),
        content: const Text(
          'Все заказы будут удалены из БД, список чатов и диалогов также очистится. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Очистить всё'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final orderRepo = ref.read(orderRepositoryProvider.notifier);
    final success = await orderRepo.clearAllOrders();
    ref.read(chatRepositoryProvider.notifier).clearAllChats();
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заказы и диалоги очищены')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка сервера. Проверьте доступность API и POST /orders/clear-all.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = isDesktopPlatform;
    final canOrg = ref.watch(authProvider).user?.effectiveCanManageOrgSettings ?? false;
    final backgroundColor = isDesktop ? AppColorsDesktop.background : AppColors.background;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: DesktopSettingsWorkspace(onDangerClearOrders: _confirmClearAllOrders),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final orgId = ref.read(authProvider).user?.organizationId;
          await ref.read(settingsRepositoryProvider.notifier).load(orgId);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
          if (!canOrg)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Настройки организации недоступны для вашей учётной записи.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          ListTile(
            leading: Icon(
              Icons.build_circle_outlined,
              color: canOrg ? AppColors.textSecondary : AppColors.textTertiary,
            ),
            title: const Text('Услуги и цены'),
            subtitle: const Text('Категории и позиции с ценой и длительностью'),
            trailing: const Icon(Icons.chevron_right),
            enabled: canOrg,
            onTap: canOrg
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ServicesSettingsScreen()),
                    )
                : null,
          ),
          ListTile(
            leading: Icon(
              Icons.directions_car_outlined,
              color: canOrg ? AppColors.textSecondary : AppColors.textTertiary,
            ),
            title: const Text('Специализация по маркам'),
            subtitle: const Text('Марки автомобилей'),
            trailing: const Icon(Icons.chevron_right),
            enabled: canOrg,
            onTap: canOrg
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BrandsSettingsScreen()),
                    )
                : null,
          ),
          ListTile(
            leading: Icon(
              Icons.schedule_rounded,
              color: canOrg ? AppColors.textSecondary : AppColors.textTertiary,
            ),
            title: const Text('Слоты и подтверждение'),
            subtitle: const Text('Длительность слота, таймаут подтверждения'),
            trailing: const Icon(Icons.chevron_right),
            enabled: canOrg,
            onTap: canOrg
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SlotsSettingsScreen()),
                    )
                : null,
          ),
          ListTile(
            leading: Icon(
              Icons.notifications_outlined,
              color: canOrg ? AppColors.textSecondary : AppColors.textTertiary,
            ),
            title: const Text('Уведомления'),
            subtitle: const Text('Push по типам событий'),
            trailing: const Icon(Icons.chevron_right),
            enabled: canOrg,
            onTap: canOrg
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationsSettingsScreen()),
                    )
                : null,
          ),
          ListTile(
            leading: Icon(
              Icons.message_outlined,
              color: canOrg ? AppColors.textSecondary : AppColors.textTertiary,
            ),
            title: const Text('Шаблоны сообщений'),
            subtitle: const Text('Для чата с клиентами'),
            trailing: const Icon(Icons.chevron_right),
            enabled: canOrg,
            onTap: canOrg
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MessageTemplatesScreen()),
                    )
                : null,
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Опасная зона',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.delete_sweep_rounded, color: AppColors.error),
            title: const Text('Очистить все заказы'),
            subtitle: const Text('Удалить все заказы из БД и очистить диалоги. Нельзя отменить.'),
            trailing: const Icon(Icons.chevron_right),
            enabled: canOrg,
            onTap: canOrg ? () => _confirmClearAllOrders(context, ref) : null,
          ),
        ],
        ),
      ),
    );
  }
}
