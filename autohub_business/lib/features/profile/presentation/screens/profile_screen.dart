import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/platform_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/organization_repository.dart';
import '../../../../shared/widgets/organization_switch_sheet.dart';
import 'organization_settings_screen.dart';
import 'staff_screen.dart';
import '../../../clients/presentation/screens/clients_screen.dart';
import '../../../cars/presentation/screens/profile_cars_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../chats/presentation/screens/chat_detail_screen.dart';
import '../../../../core/repositories/chat_repository.dart';
import 'incoming_invitations_screen.dart';
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Профиль'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user != null) ...[
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.3),
                    child: Text(
                      user.initials,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.displayName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.role.label,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
          Consumer(
            builder: (context, ref, _) {
              final orgAsync = ref.watch(organizationProvider);
              final orgName = orgAsync.valueOrNull?.name ?? 'Организация';
              return ListTile(
                leading: const Icon(Icons.business_rounded, color: AppColors.textSecondary),
                title: const Text('Организация'),
                subtitle: Text(orgName),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OrganizationSettingsScreen(),
                  ),
                ),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final u = ref.watch(authProvider).user;
              if (u == null || !u.hasMultipleOrganizations) return const SizedBox.shrink();
              return ListTile(
                leading: const Icon(Icons.swap_horiz_rounded, color: AppColors.textSecondary),
                title: const Text('Сменить организацию'),
                subtitle: const Text('Переключиться на другую точку'),
                onTap: () => showOrganizationSwitchSheet(context, ref),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final canSeeClients = ref.watch(authProvider).user?.role.canSeeClients ?? false;
              if (!canSeeClients) return const SizedBox.shrink();
              return ListTile(
                leading: const Icon(Icons.people_outline_rounded, color: AppColors.textSecondary),
                title: const Text('Клиенты'),
                subtitle: const Text('Список ваших клиентов'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ClientsScreen()),
                ),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final canSeeStaff = ref.watch(authProvider).user?.role.canSeeStaff ?? false;
              if (!canSeeStaff) return const SizedBox.shrink();
              return ListTile(
                leading: const Icon(Icons.people_rounded, color: AppColors.textSecondary),
                title: const Text('Персонал'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StaffScreen()),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline_rounded, color: AppColors.textSecondary),
            title: const Text('Входящие приглашения'),
            subtitle: const Text('Принять или отклонить приглашение в организацию'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const IncomingInvitationsScreen()),
            ),
          ),
          if (!isDesktopPlatform)
            ListTile(
              leading: const Icon(Icons.directions_car_rounded, color: AppColors.textSecondary),
              title: const Text('Автомобили'),
              subtitle: const Text('Список автомобилей по заказам'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileCarsScreen()),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.support_agent_rounded, color: AppColors.textSecondary),
            title: const Text('Написать в поддержку'),
            subtitle: const Text('Чат с командой AutoHub'),
            onTap: () async {
              final r = await ref.read(chatRepositoryProvider.notifier).openSupportChat();
              if (!context.mounted) return;
              final preview = r.dataOrNull;
              if (preview != null) {
                await ensureChatDataLoaded(ref, preview.id, refValid: () => context.mounted);
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ChatDetailScreen(chatId: preview.id)),
                );
              } else {
                final err = r.errorOrNull;
                if (err != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message)));
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_rounded, color: AppColors.textSecondary),
            title: const Text('Настройки'),
            subtitle: const Text('Услуги, цены, марки, слоты, уведомления, шаблоны'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const Divider(color: AppColors.border),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.error),
            title: const Text(
              'Выйти',
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w500),
            ),
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              // Состояние auth изменится — main.dart покажет WelcomeScreen
            },
          ),
        ],
      ),
    );
  }
}
