import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/config/platform_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors_desktop.dart';

/// После входа — выбор организации, если у аккаунта их несколько.
class SelectOrganizationScreen extends ConsumerWidget {
  const SelectOrganizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final desktop = isDesktopPlatform;
    final bg = desktop ? AppColorsDesktop.background : AppColors.background;
    final surface = desktop ? AppColorsDesktop.surface : AppColors.cardBg;
    final primary = desktop ? AppColorsDesktop.primary : AppColors.primary;
    final textPrimary = desktop ? AppColorsDesktop.textPrimary : AppColors.textPrimary;
    final textSecondary = desktop ? AppColorsDesktop.textSecondary : AppColors.textSecondary;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/login');
      });
      return Scaffold(backgroundColor: bg, body: const Center(child: CircularProgressIndicator()));
    }

    final orgs = user.organizations;
    if (orgs.length <= 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/app');
      });
      return Scaffold(backgroundColor: bg, body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        title: Text('Выберите организацию', style: TextStyle(color: textPrimary)),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: orgs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final o = orgs[i];
          final selected = o.id == user.organizationId;
          return Material(
            color: surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                if (o.id == user.organizationId) {
                  context.go('/app');
                  return;
                }
                final r = await ref.read(authProvider.notifier).switchOrganization(o.id);
                if (!context.mounted) return;
                r.when(
                  success: (_) => context.go('/app'),
                  failure: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message))),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                child: Row(
                  children: [
                    Icon(Icons.business_rounded, color: primary, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            BusinessRole.fromString(o.role).label,
                            style: TextStyle(fontSize: 13, color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (selected) Icon(Icons.check_circle_rounded, color: primary),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
