import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/organization_repository.dart';
import '../../../../core/repositories/order_repository.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../core/repositories/staff_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/theme/desktop_design_system.dart';
import '../../../../core/theme/desktop_light_theme.dart';
import '../../../settings/presentation/screens/services_settings_screen.dart';
import '../../../settings/presentation/screens/slots_settings_screen.dart';
import '../screens/organization_settings_screen.dart';

/// Диалог ввода названия новой организации.
class CreateOrganizationNameDialog extends StatefulWidget {
  const CreateOrganizationNameDialog({super.key, this.desktopChrome = false});

  final bool desktopChrome;

  @override
  State<CreateOrganizationNameDialog> createState() => _CreateOrganizationNameDialogState();
}

class _CreateOrganizationNameDialogState extends State<CreateOrganizationNameDialog> {
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dialog = AlertDialog(
      title: const Text('Новая организация'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Название',
          hintText: 'Например, Автосервис на Юге',
        ),
        autofocus: true,
        textCapitalization: TextCapitalization.words,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(
          onPressed: () {
            final t = _controller.text.trim();
            if (t.isEmpty) return;
            Navigator.pop(context, t);
          },
          child: const Text('Создать'),
        ),
      ],
    );
    if (widget.desktopChrome) {
      return themeDesktopLight(child: dialog);
    }
    return dialog;
  }
}

/// После первого создания организации самозанятым — подсказка по шагам настройки.
Future<void> showSoloOrganizationSetupDialog(
  BuildContext context,
  WidgetRef ref, {
  required bool desktopChrome,
}) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      Widget child = AlertDialog(
        title: const Text('Настройте сервис'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Организация создана. Чтобы клиенты видели вас на карте и могли записаться:',
                style: TextStyle(
                  height: 1.4,
                  color: desktopChrome ? AppColorsDesktop.textSecondary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              _SetupLinkTile(
                desktopChrome: desktopChrome,
                icon: Icons.place_outlined,
                label: 'Адрес и точка на карте',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => OrganizationSettingsScreen(desktopChrome: desktopChrome),
                    ),
                  );
                },
              ),
              _SetupLinkTile(
                desktopChrome: desktopChrome,
                icon: Icons.build_circle_outlined,
                label: 'Услуги и цены',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => const ServicesSettingsScreen()),
                  );
                },
              ),
              _SetupLinkTile(
                desktopChrome: desktopChrome,
                icon: Icons.schedule_rounded,
                label: 'Слоты и рабочий день',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => const SlotsSettingsScreen()),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Позже'),
          ),
        ],
      );
      if (desktopChrome) {
        child = themeDesktopLight(child: child);
      }
      return child;
    },
  );
}

class _SetupLinkTile extends StatelessWidget {
  const _SetupLinkTile({
    required this.desktopChrome,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool desktopChrome;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconC = desktopChrome ? AppColorsDesktop.primary : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: desktopChrome ? AppColorsDesktop.nestedBg : AppColors.cardBg,
        borderRadius: BorderRadius.circular(desktopChrome ? DesktopDesignSystem.radiusButton : 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(desktopChrome ? DesktopDesignSystem.radiusButton : 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: iconC, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: desktopChrome ? AppColorsDesktop.textPrimary : AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: desktopChrome ? AppColorsDesktop.textSecondary : AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Создание организации и при необходимости онбординг для самозанятого (первый раз без точки).
Future<void> createOrganizationWithOptionalSoloOnboarding(
  BuildContext context,
  WidgetRef ref, {
  required bool desktopChrome,
}) async {
  final hadNoOrg = ref.read(authProvider).user?.effectiveOrganizationId == null;
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => CreateOrganizationNameDialog(desktopChrome: desktopChrome),
  );
  if (name == null || name.trim().isEmpty) return;
  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final r = await ref.read(authProvider.notifier).createAdditionalOrganization(name: name.trim());
  if (!context.mounted) return;

  final err = r.errorOrNull;
  if (err != null) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(err.message),
        backgroundColor: desktopChrome ? AppColorsDesktop.error : AppColors.error,
      ),
    );
    return;
  }

  final id = ref.read(authProvider).user?.effectiveOrganizationId;
  await ref.read(organizationRepositoryProvider.notifier).load(id);
  await ref.read(staffRepositoryProvider.notifier).load(id);
  await ref.read(settingsRepositoryProvider.notifier).load(id);
  ref.read(orderRepositoryProvider.notifier).loadFromApi();

  messenger.showSnackBar(
    SnackBar(
      content: const Text('Организация создана'),
      backgroundColor: desktopChrome ? AppColorsDesktop.nestedBg : AppColors.cardBg,
    ),
  );

  final solo = ref.read(authProvider).user?.role == BusinessRole.solo;
  if (hadNoOrg && solo && context.mounted) {
    await showSoloOrganizationSetupDialog(context, ref, desktopChrome: desktopChrome);
  }
}
