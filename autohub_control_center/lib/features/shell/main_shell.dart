import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/api/internal_data_providers.dart';
import '../../../core/constants/internal_roles.dart';
import '../../../core/theme/app_colors.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child, required this.currentLocation});

  final Widget child;
  final String currentLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final role = user?.role ?? InternalRole.analyst;
    final location = currentLocation;
    final visibleSections = kAllNavSections.where((s) => role.canAccessSection(s.sectionId)).toList();
    final supportUnreadTotal = role.canAccessSection('support-chats')
        ? ref.watch(supportChatsProvider).maybeWhen(
              data: (chats) => chats.fold<int>(
                0,
                (s, c) => s + ((c['unread_count'] as num?)?.toInt() ?? 0),
              ),
              orElse: () => 0,
            )
        : 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          Container(
            width: 248,
            color: AppColors.sidebarBg,
            child: Column(
              children: [
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Control Center',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: visibleSections.map((section) {
                      final selected = location == section.path || (section.path == '/app' && location == '/app');
                      final showSupportBadge =
                          section.sectionId == 'support-chats' && supportUnreadTotal > 0 && role.canAccessSection('support-chats');
                      return ListTile(
                        leading: Icon(
                          section.icon,
                          color: selected ? AppColors.primary : AppColors.navInactive,
                          size: 22,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                section.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                  color: selected ? AppColors.primary : AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (showSupportBadge) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.danger,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  supportUnreadTotal > 99 ? '99+' : '$supportUnreadTotal',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        selected: selected,
                        onTap: () => context.go(section.path),
                      );
                    }).toList(),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user?.name ?? '—',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        user?.role.label ?? '—',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        AppConfig.environment,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () async {
                          await ref.read(authProvider.notifier).logout();
                          if (context.mounted) context.go('/login');
                        },
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text('Выход'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  alignment: Alignment.centerLeft,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Text(
                    user?.name ?? 'Оператор',
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
