import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/chat_repository.dart';
import '../../../chats/presentation/screens/chat_detail_screen.dart';
import 'account_settings_screen.dart';
import '../widgets/invitation_count_badge.dart';
import '../providers/pending_invitations_count_provider.dart';
import '../widgets/organization_home_card.dart';
import '../widgets/user_profile_avatar.dart';
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
                  const UserProfileAvatar(radius: 40),
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
                  if (user.phone.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      user.phone,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          Consumer(
            builder: (context, ref, _) {
              final pendingAsync = ref.watch(pendingInvitationsCountProvider);
              final pending = pendingAsync.valueOrNull ?? 0;
              return ListTile(
                leading: const Icon(Icons.manage_accounts_outlined, color: AppColors.textSecondary),
                title: const Text('Настройки аккаунта'),
                subtitle: const Text('Почта, телефон, организация, приглашения'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InvitationCountBadge(count: pending),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                  ],
                ),
                onTap: () async {
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const AccountSettingsScreen()),
                  );
                  ref.invalidate(pendingInvitationsCountProvider);
                },
              );
            },
          ),
          const SizedBox(height: 8),
          const OrganizationHomeCard(),
          ListTile(
            leading: const Icon(Icons.support_agent_rounded, color: AppColors.textSecondary),
            title: const Text('Написать в поддержку'),
            subtitle: const Text('Чат с командой MP-Servis'),
            onTap: () async {
              final r = await ref.read(chatRepositoryProvider.notifier).openSupportChat();
              if (!context.mounted) return;
              final preview = r.dataOrNull;
              if (preview != null) {
                await ensureChatDataLoaded(ref, preview.id, refValid: () => context.mounted);
                if (!context.mounted) return;
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(builder: (_) => ChatDetailScreen(chatId: preview.id)),
                );
              } else {
                final err = r.errorOrNull;
                if (err != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message)));
                }
              }
            },
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
            },
          ),
        ],
      ),
    );
  }
}
