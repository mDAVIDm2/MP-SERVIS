import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/organization_repository.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../shared/widgets/organization_switch_sheet.dart';
import '../screens/organization_service_hub_screen.dart';
import '../screens/organization_settings_screen.dart';
import '../screens/staff_desktop_screen.dart';
import 'create_organization_flow.dart';

/// Десктоп «Мой сервис»: одна карточка — шапка, вкладки «Мой сервис» / «Персонал», контент.
class OrganizationDesktopWorkspace extends ConsumerStatefulWidget {
  const OrganizationDesktopWorkspace({super.key, required this.onDangerClearOrders});

  final Future<void> Function(BuildContext context, WidgetRef ref) onDangerClearOrders;

  @override
  ConsumerState<OrganizationDesktopWorkspace> createState() => _OrganizationDesktopWorkspaceState();
}

class _OrganizationDesktopWorkspaceState extends ConsumerState<OrganizationDesktopWorkspace>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  int _tabLength = 0;

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _syncTabController(int length) {
    if (_tabController != null && _tabLength == length) return;
    _tabController?.dispose();
    _tabLength = length;
    _tabController = TabController(length: length, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) {
      return const ColoredBox(color: AppColorsDesktop.background, child: SizedBox.expand());
    }
    final hasOrg = user.effectiveOrganizationId != null && user.effectiveOrganizationId!.isNotEmpty;
    final soloEmpty = user.role == BusinessRole.solo && !hasOrg;

    if (soloEmpty) {
      return ColoredBox(
        color: AppColorsDesktop.background,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.storefront_outlined, size: 72, color: AppColorsDesktop.primary.withValues(alpha: 0.9)),
                  const SizedBox(height: 20),
                  const Text(
                    'Мой сервис',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColorsDesktop.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Организация ещё не создана. После создания настройте адрес на карте, услуги и слоты.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, height: 1.45, color: AppColorsDesktop.textSecondary),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: () => createOrganizationWithOptionalSoloOnboarding(context, ref, desktopChrome: true),
                    icon: const Icon(Icons.add_business_rounded),
                    label: const Text('Создать организацию'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColorsDesktop.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final showStaff = user.role.canInviteStaff;
    final canOpenServiceHub = user.effectiveCanManageOrgSettings;
    final len = showStaff ? 2 : 1;
    _syncTabController(len);

    final orgAsync = ref.watch(organizationProvider);
    final orgName = (orgAsync.valueOrNull?.name.trim().isNotEmpty == true)
        ? orgAsync.valueOrNull!.name
        : 'Организация';
    final tc = _tabController!;

    const orgDataBody = OrganizationSettingsScreen(
      desktopChrome: true,
      desktopEmbedInWorkspace: true,
    );

    void openHub() {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => OrganizationServiceHubScreen(
            useDesktopChrome: true,
            onDangerClearOrders: widget.onDangerClearOrders,
          ),
        ),
      );
    }

    return ColoredBox(
      color: AppColorsDesktop.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColorsDesktop.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColorsDesktop.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  orgName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                    color: AppColorsDesktop.textPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  canOpenServiceHub
                                      ? 'Ниже — контакты и точка на карте. Прайс, слоты и уведомления — в настройках сервиса.'
                                      : 'Правка услуг и расписания недоступна для вашей роли.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: AppColorsDesktop.textSecondary.withValues(alpha: 0.95),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (canOpenServiceHub) ...[
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: openHub,
                              icon: const Icon(Icons.tune_rounded, size: 18),
                              label: const Text('Настройка сервиса'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColorsDesktop.primary,
                                side: BorderSide(color: AppColorsDesktop.primary.withValues(alpha: 0.35)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (user.hasMultipleOrganizations)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => showOrganizationSwitchSheet(context, ref),
                            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                            label: const Text('Сменить организацию'),
                            style: TextButton.styleFrom(foregroundColor: AppColorsDesktop.primary),
                          ),
                        ),
                      ),
                    if (showStaff)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                        child: TabBar(
                          controller: tc,
                          labelColor: AppColorsDesktop.primary,
                          unselectedLabelColor: AppColorsDesktop.textSecondary,
                          indicatorColor: AppColorsDesktop.primary,
                          indicatorWeight: 3,
                          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          tabs: const [
                            Tab(text: 'Мой сервис'),
                            Tab(text: 'Персонал'),
                          ],
                        ),
                      )
                    else
                      const SizedBox(height: 4),
                    const Divider(height: 1, color: AppColorsDesktop.border),
                    Expanded(
                      child: showStaff
                          ? TabBarView(
                              controller: tc,
                              children: [
                                orgDataBody,
                                const StaffDesktopScreen(),
                              ],
                            )
                          : orgDataBody,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
