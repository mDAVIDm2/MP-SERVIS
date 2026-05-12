import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/organization_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/organization_switch_sheet.dart';
import '../screens/organization_service_hub_screen.dart';
import 'create_organization_flow.dart';
import '../screens/staff_screen.dart';
import '../../../clients/presentation/screens/clients_screen.dart';
import '../../../cars/presentation/screens/profile_cars_screen.dart';
import '../../../inventory/presentation/screens/inventory_mobile_screen.dart';

/// Блок «Мой автосервис» на профиле: шапка → карточка сервиса; ниже только строки переходов (как на десктопе).
class OrganizationHomeCard extends ConsumerWidget {
  const OrganizationHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();

    final showClients = user.role.canSeeClients;
    /// Персонал и приглашения — только владелец, админ, самозанятый (не мастер).
    final canOpenStaff = user.role.canInviteStaff;
    final canOpenWarehouse = user.role != BusinessRole.master;
    final canOrgHub = user.effectiveCanManageOrgSettings;
    final soloHint = user.role == BusinessRole.solo;
    final orgAsync = ref.watch(organizationProvider);
    final hasOrg = user.effectiveOrganizationId != null && user.effectiveOrganizationId!.isNotEmpty;
    final soloEmpty = user.role == BusinessRole.solo && !hasOrg;
    final orgName = soloEmpty
        ? 'Мой сервис'
        : (orgAsync.valueOrNull?.name.trim().isNotEmpty == true
            ? orgAsync.valueOrNull!.name
            : 'Моя организация');

    final iconC = AppColors.textSecondary;

    if (soloEmpty) {
      return Card(
        clipBehavior: Clip.antiAlias,
        color: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border.withValues(alpha: 0.85)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                orgName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
              const SizedBox(height: 8),
              Text(
                'Создайте организацию — появитесь на карте у клиентов и сможете вести запись.',
                style: TextStyle(fontSize: 14, height: 1.35, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => createOrganizationWithOptionalSoloOnboarding(context, ref, desktopChrome: false),
                icon: const Icon(Icons.add_business_rounded),
                label: const Text('Создать организацию'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      color: AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            title: Text(
              orgName,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            subtitle: Text(
              canOrgHub
                  ? 'Настройка сервиса: услуги, марки, слоты, уведомления…'
                  : 'Настройки сервиса недоступны для вашей роли',
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            enabled: canOrgHub,
            onTap: canOrgHub
                ? () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(builder: (_) => const OrganizationServiceHubScreen()),
                    );
                  }
                : null,
          ),
          if (user.hasMultipleOrganizations)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => showOrganizationSwitchSheet(context, ref),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                  label: const Text('Сменить организацию'),
                ),
              ),
            ),
          Divider(height: 1, color: AppColors.border.withValues(alpha: 0.65)),
          if (showClients)
            ListTile(
              leading: Icon(Icons.people_outline_rounded, color: iconC),
              title: const Text('Клиенты'),
              subtitle: const Text('По заказам организации'),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const ClientsScreen()),
              ),
            ),
          ListTile(
            leading: Icon(Icons.directions_car_rounded, color: iconC),
            title: const Text('Автомобили'),
            subtitle: const Text('Обслуживались в этой организации'),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(builder: (_) => const ProfileCarsScreen()),
            ),
          ),
          if (canOpenWarehouse)
            ListTile(
              leading: Icon(Icons.warehouse_rounded, color: iconC),
              title: const Text('Склад'),
              subtitle: const Text('Остатки, движения, закупки'),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const InventoryMobileScreen()),
              ),
            ),
          if (canOpenStaff)
            ListTile(
              leading: Icon(Icons.groups_rounded, color: iconC),
              title: const Text('Персонал'),
              subtitle: Text(
                user.role.canSeeStaff
                    ? 'Сотрудники, график и приглашения'
                    : soloHint
                        ? 'Ваш график в расписании; можно пригласить мастера'
                        : 'Кто работает в организации',
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const StaffScreen()),
              ),
            ),
        ],
      ),
    );
  }
}
