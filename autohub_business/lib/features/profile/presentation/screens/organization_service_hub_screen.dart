import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/theme/desktop_light_theme.dart';
import '../../../settings/presentation/widgets/settings_business_desktop_body.dart';
import '../../../settings/presentation/screens/services_settings_screen.dart';
import '../../../settings/presentation/screens/brands_settings_screen.dart';
import '../../../settings/presentation/screens/slots_settings_screen.dart';
import '../../../settings/presentation/screens/notifications_settings_screen.dart';
import '../../../settings/presentation/screens/message_templates_screen.dart';
import 'organization_settings_screen.dart';
import 'subscription_tariff_screen.dart';
import 'staff_desktop_screen.dart';
import 'staff_screen.dart';
import '../../../clients/presentation/screens/clients_screen.dart';
import '../../../cars/presentation/screens/profile_cars_screen.dart';
import '../widgets/create_organization_flow.dart';

/// Настройка сервиса: прайс, слоты, уведомления и быстрые переходы (те же экраны модулей).
class OrganizationServiceHubScreen extends ConsumerWidget {
  const OrganizationServiceHubScreen({
    super.key,
    this.useDesktopChrome = false,
    this.onDangerClearOrders,
  });

  /// Светлая оболочка для окна из десктоп-настроек.
  final bool useDesktopChrome;

  /// Для десктопа: очистка заказов из [SettingsBusinessDesktopBody].
  final Future<void> Function(BuildContext context, WidgetRef ref)? onDangerClearOrders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final d = useDesktopChrome;
    final hasOrg =
        user != null && user.effectiveOrganizationId != null && user.effectiveOrganizationId!.isNotEmpty;
    final soloEmpty = user != null && user.role == BusinessRole.solo && !hasOrg;

    if (soloEmpty) {
      final empty = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.storefront_outlined,
                  size: 56,
                  color: d ? AppColorsDesktop.primary : AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Сначала создайте организацию',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: d ? AppColorsDesktop.textPrimary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Тогда откроются настройки услуг, слотов и карточки на карте.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    height: 1.4,
                    color: d ? AppColorsDesktop.textSecondary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => createOrganizationWithOptionalSoloOnboarding(context, ref, desktopChrome: d),
                  icon: const Icon(Icons.add_business_rounded),
                  label: const Text('Создать организацию'),
                  style: FilledButton.styleFrom(
                    backgroundColor: d ? AppColorsDesktop.primary : AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (d) {
        return themeDesktopLight(
          child: Scaffold(
            backgroundColor: AppColorsDesktop.background,
            appBar: AppBar(
              title: const Text('Настройка сервиса'),
              backgroundColor: AppColorsDesktop.surface,
              foregroundColor: AppColorsDesktop.textPrimary,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
            ),
            body: empty,
          ),
        );
      }
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Настройка сервиса')),
        body: empty,
      );
    }

    final canManageStaff = user?.role.canInviteStaff ?? false;
    final canClients = user?.role.canSeeClients ?? false;
    final canOrg = user?.effectiveCanManageOrgSettings ?? false;
    final iconC = d ? AppColorsDesktop.textSecondary : AppColors.textSecondary;
    final divC = d ? AppColorsDesktop.border : AppColors.border;

    final tariffTile = ListTile(
      leading: Icon(Icons.workspace_premium_outlined, color: iconC),
      title: const Text('Тариф'),
      subtitle: const Text('План, лимиты и расход'),
      trailing: Icon(Icons.chevron_right_rounded, color: iconC),
      onTap: () => Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => const SubscriptionTariffScreen()),
      ),
    );

    final orgTile = ListTile(
      leading: Icon(Icons.business_rounded, color: canOrg ? iconC : iconC.withValues(alpha: 0.45)),
      title: const Text('Данные организации'),
      subtitle: Text(
        canOrg
            ? 'Название, адрес, телефон, режим записи'
            : 'Просмотр и правка недоступны для вашей роли',
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: iconC),
      enabled: canOrg,
      onTap: canOrg
          ? () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => OrganizationSettingsScreen(desktopChrome: d),
                ),
              )
          : null,
    );

    final topShortcuts = <Widget>[
      if (canClients && !d)
        ListTile(
          leading: Icon(Icons.people_outline_rounded, color: iconC),
          title: const Text('Клиенты'),
          subtitle: const Text('Список клиентов по заказам'),
          trailing: Icon(Icons.chevron_right_rounded, color: iconC),
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute<void>(builder: (_) => const ClientsScreen()),
          ),
        ),
      if (!d)
        ListTile(
          leading: Icon(Icons.directions_car_rounded, color: iconC),
          title: const Text('Автомобили'),
          subtitle: const Text('По заказам организации'),
          trailing: Icon(Icons.chevron_right_rounded, color: iconC),
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute<void>(builder: (_) => const ProfileCarsScreen()),
          ),
        ),
      if (!d && canManageStaff)
        ListTile(
          leading: Icon(Icons.groups_rounded, color: iconC),
          title: const Text('Персонал'),
          subtitle: const Text('Сотрудники и приглашения'),
          trailing: Icon(Icons.chevron_right_rounded, color: iconC),
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute<void>(builder: (_) => const StaffScreen()),
          ),
        ),
    ];

    final body = ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        tariffTile,
        orgTile,
        Divider(height: 24, color: divC),
        ...topShortcuts,
        if (topShortcuts.isNotEmpty) Divider(height: 24, color: divC),
        if (!canOrg)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Услуги, слоты, марки и шаблоны доступны только сотрудникам с правом «Настройки организации».',
              style: TextStyle(fontSize: 13, height: 1.35, color: iconC),
            ),
          ),
        ListTile(
          leading: Icon(Icons.build_circle_outlined, color: canOrg ? iconC : iconC.withValues(alpha: 0.45)),
          title: const Text('Услуги и цены'),
          subtitle: const Text('Категории, цены, длительность'),
          trailing: Icon(Icons.chevron_right_rounded, color: iconC),
          enabled: canOrg,
          onTap: canOrg
              ? () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const ServicesSettingsScreen()),
                  )
              : null,
        ),
        ListTile(
          leading: Icon(Icons.directions_car_outlined, color: canOrg ? iconC : iconC.withValues(alpha: 0.45)),
          title: const Text('Специализация по маркам'),
          trailing: Icon(Icons.chevron_right_rounded, color: iconC),
          enabled: canOrg,
          onTap: canOrg
              ? () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const BrandsSettingsScreen()),
                  )
              : null,
        ),
        ListTile(
          leading: Icon(Icons.schedule_rounded, color: canOrg ? iconC : iconC.withValues(alpha: 0.45)),
          title: const Text('Слоты и подтверждение'),
          trailing: Icon(Icons.chevron_right_rounded, color: iconC),
          enabled: canOrg,
          onTap: canOrg
              ? () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const SlotsSettingsScreen()),
                  )
              : null,
        ),
        ListTile(
          leading: Icon(Icons.message_outlined, color: canOrg ? iconC : iconC.withValues(alpha: 0.45)),
          title: const Text('Шаблоны сообщений'),
          trailing: Icon(Icons.chevron_right_rounded, color: iconC),
          enabled: canOrg,
          onTap: canOrg
              ? () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const MessageTemplatesScreen()),
                  )
              : null,
        ),
        ListTile(
          leading: Icon(Icons.notifications_outlined, color: canOrg ? iconC : iconC.withValues(alpha: 0.45)),
          title: const Text('Уведомления'),
          trailing: Icon(Icons.chevron_right_rounded, color: iconC),
          enabled: canOrg,
          onTap: canOrg
              ? () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const NotificationsSettingsScreen()),
                  )
              : null,
        ),
      ],
    );

    if (d) {
      final danger = onDangerClearOrders ?? (BuildContext ctx, WidgetRef r) async {};
      if (!canManageStaff) {
        return themeDesktopLight(
          child: Scaffold(
            backgroundColor: AppColorsDesktop.background,
            appBar: AppBar(
              title: const Text('Настройка сервиса'),
              backgroundColor: AppColorsDesktop.surface,
              foregroundColor: AppColorsDesktop.textPrimary,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
            ),
            body: SettingsBusinessDesktopBody(onDangerClearOrders: danger),
          ),
        );
      }
      return themeDesktopLight(
        child: DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: AppColorsDesktop.background,
            appBar: AppBar(
              title: const Text('Настройка сервиса'),
              backgroundColor: AppColorsDesktop.surface,
              foregroundColor: AppColorsDesktop.textPrimary,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(46),
                child: Material(
                  color: AppColorsDesktop.surface,
                  child: TabBar(
                    labelColor: AppColorsDesktop.primary,
                    unselectedLabelColor: AppColorsDesktop.textSecondary,
                    indicatorColor: AppColorsDesktop.primary,
                    dividerColor: AppColorsDesktop.border,
                    tabs: const [
                      Tab(text: 'Разделы'),
                      Tab(text: 'Персонал'),
                    ],
                  ),
                ),
              ),
            ),
            body: TabBarView(
              children: [
                SettingsBusinessDesktopBody(onDangerClearOrders: danger),
                const StaffDesktopScreen(),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Настройка сервиса'),
      ),
      body: body,
    );
  }
}
