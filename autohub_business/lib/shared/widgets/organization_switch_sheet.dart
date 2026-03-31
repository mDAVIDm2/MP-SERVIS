import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_desktop.dart';
import '../../core/config/platform_utils.dart';

/// Список организаций для переключения активной (бизнес-контекст).
Future<void> showOrganizationSwitchSheet(BuildContext context, WidgetRef ref) async {
  final user = ref.read(authProvider).user;
  if (user == null || !user.hasMultipleOrganizations) return;

  final desktop = isDesktopPlatform;
  final bg = desktop ? AppColorsDesktop.surface : AppColors.cardBg;
  final textPrimary = desktop ? AppColorsDesktop.textPrimary : AppColors.textPrimary;
  final textSecondary = desktop ? AppColorsDesktop.textSecondary : AppColors.textSecondary;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Сменить организацию',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
            ),
            ...user.organizations.map((o) {
              final selected = o.id == user.organizationId;
              return ListTile(
                title: Text(o.name, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w500)),
                subtitle: Text(
                  BusinessRole.fromString(o.role).label,
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
                trailing: selected
                    ? Icon(Icons.check_rounded, color: desktop ? AppColorsDesktop.primary : AppColors.primary)
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  if (o.id == user.organizationId) return;
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  final r = await ref.read(authProvider.notifier).switchOrganization(o.id);
                  if (!context.mounted) return;
                  r.when(
                    success: (_) {},
                    failure: (e) => messenger?.showSnackBar(SnackBar(content: Text(e.message))),
                  );
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
