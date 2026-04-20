import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/desktop_light_theme.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../profile/presentation/screens/account_settings_body.dart';
import '../../../profile/presentation/widgets/organization_desktop_workspace.dart';

/// Подвкладка десктопных «Настройки»: 0 — аккаунт, 1 — мой сервис. Синхронизируется с сайдбаром.
final settingsDesktopSubTabProvider = StateProvider<int>((ref) => 0);

/// Десктоп: «Настройки» — переключение только через боковое меню ([settingsDesktopSubTabProvider]).
class DesktopSettingsWorkspace extends ConsumerWidget {
  const DesktopSettingsWorkspace({super.key, required this.onDangerClearOrders});

  final Future<void> Function(BuildContext context, WidgetRef ref) onDangerClearOrders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final showOrgTab = user?.effectiveCanManageOrgSettings ?? false;

    var sub = ref.watch(settingsDesktopSubTabProvider);
    if (!showOrgTab && sub != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(settingsDesktopSubTabProvider.notifier).state = 0;
      });
    }
    final safeSub = showOrgTab ? sub.clamp(0, 1) : 0;

    return themeDesktopLight(
      child: IndexedStack(
        index: showOrgTab ? safeSub : 0,
        sizing: StackFit.expand,
        children: showOrgTab
            ? [
                const AccountSettingsBody(desktopChrome: true),
                OrganizationDesktopWorkspace(onDangerClearOrders: onDangerClearOrders),
              ]
            : const [
                AccountSettingsBody(desktopChrome: true),
              ],
      ),
    );
  }
}
