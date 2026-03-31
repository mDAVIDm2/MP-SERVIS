import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/platform_utils.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_desktop.dart';
import '../../core/theme/desktop_design_system.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/repositories/order_repository.dart';
import '../../core/repositories/chat_repository.dart';
import '../../core/repositories/organization_repository.dart';
import 'organization_switch_sheet.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/orders/presentation/screens/orders_screen.dart';
import '../../features/orders/presentation/utils/order_items_loader.dart';
import '../../features/schedule/presentation/screens/schedule_screen.dart';
import '../../features/chats/presentation/screens/chats_screen.dart';
import '../../features/master_tasks/presentation/screens/master_tasks_screen.dart';
import '../../features/master_tasks/presentation/screens/master_schedule_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/finance/presentation/screens/finance_screen.dart';
import '../../features/cars/presentation/screens/cars_screen.dart';
import '../../features/orders/presentation/screens/quick_create_order_screen.dart';

/// Ширина экрана, с которой показываем боковое меню (Web/Desktop).
const double _kBreakpointWide = 600;

/// Оболочка с навигацией в зависимости от роли (Owner/Admin/Master/Solo).
/// На узком экране — нижняя панель; на широком (Web/Desktop) — боковое меню.
class MainShell extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const MainShell({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> with WidgetsBindingObserver {
  late int _currentIndex;
  final GlobalKey<NavigatorState> _contentNavigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ref.read(orderRepositoryProvider.notifier).loadFromApi();
      if (!mounted) return;
      await ensureAllEmptyOrdersLoaded(ref, refValid: () => mounted);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.read(orderRepositoryProvider.notifier).loadFromApi();
      ref.read(chatRepositoryProvider.notifier).loadFromApi();
    }
  }

  @override
  void didUpdateWidget(MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      setState(() => _currentIndex = widget.initialTabIndex);
    }
  }

  void _onTabSelected(int i) {
    final sameTab = i == _currentIndex;
    if (!sameTab) setState(() => _currentIndex = i);
    if (context.mounted) context.go('/app?tab=$i');
    // Повторный тап по текущей вкладке не должен снова бить API (шум в логах и лишняя нагрузка при офлайне).
    if (sameTab) return;
    final role = ref.read(authProvider).user?.role ?? BusinessRole.admin;
    final desktop = isDesktopPlatform;
    final items = _itemsForRole(role, desktop: desktop);
    final label = i < items.length ? items[i].label : '';
    final isOrdersTab = label == 'Заказы' || label == 'Расписание';
    final isChatsTab = label == 'Чаты';
    if (isOrdersTab) ref.read(orderRepositoryProvider.notifier).loadFromApi();
    if (isChatsTab) ref.read(chatRepositoryProvider.notifier).loadFromApi();
  }

  static List<_NavItem> _itemsForRole(BusinessRole role, {bool desktop = false}) {
    if (role == BusinessRole.master) {
      return const [
        _NavItem(icon: Icons.task_alt_rounded, label: 'Мои задачи'),
        _NavItem(icon: Icons.calendar_today_rounded, label: 'Расписание'),
        _NavItem(icon: Icons.person_rounded, label: 'Профиль'),
      ];
    }
    if (desktop && role == BusinessRole.owner) {
      return const [
        _NavItem(icon: Icons.dashboard_rounded, label: 'Панель'),
        _NavItem(icon: Icons.calendar_today_rounded, label: 'Расписание'),
        _NavItem(icon: Icons.receipt_long_rounded, label: 'Заказы'),
        _NavItem(icon: Icons.directions_car_rounded, label: 'Автомобили'),
        _NavItem(icon: Icons.chat_bubble_rounded, label: 'Чаты'),
        _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Финансы'),
        _NavItem(icon: Icons.settings_rounded, label: 'Настройки'),
      ];
    }
    if (desktop && role == BusinessRole.admin) {
      return const [
        _NavItem(icon: Icons.calendar_today_rounded, label: 'Расписание'),
        _NavItem(icon: Icons.receipt_long_rounded, label: 'Заказы'),
        _NavItem(icon: Icons.directions_car_rounded, label: 'Автомобили'),
        _NavItem(icon: Icons.chat_bubble_rounded, label: 'Чаты'),
        _NavItem(icon: Icons.settings_rounded, label: 'Настройки'),
      ];
    }
    if (desktop && role == BusinessRole.solo) {
      return const [
        _NavItem(icon: Icons.calendar_today_rounded, label: 'Расписание'),
        _NavItem(icon: Icons.receipt_long_rounded, label: 'Заказы'),
        _NavItem(icon: Icons.directions_car_rounded, label: 'Автомобили'),
        _NavItem(icon: Icons.chat_bubble_rounded, label: 'Чаты'),
        _NavItem(icon: Icons.settings_rounded, label: 'Настройки'),
      ];
    }
    if (role == BusinessRole.owner) {
      return const [
        _NavItem(icon: Icons.dashboard_rounded, label: 'Главная'),
        _NavItem(icon: Icons.calendar_today_rounded, label: 'Расписание'),
        _NavItem(icon: Icons.receipt_long_rounded, label: 'Заказы'),
        _NavItem(icon: Icons.chat_bubble_rounded, label: 'Чаты'),
        _NavItem(icon: Icons.person_rounded, label: 'Профиль'),
      ];
    }
    return const [
      _NavItem(icon: Icons.calendar_today_rounded, label: 'Расписание'),
      _NavItem(icon: Icons.receipt_long_rounded, label: 'Заказы'),
      _NavItem(icon: Icons.chat_bubble_rounded, label: 'Чаты'),
      _NavItem(icon: Icons.person_rounded, label: 'Профиль'),
    ];
  }

  static List<Widget> _screensForRole(BusinessRole role, {bool desktop = false, int currentTabIndex = 0, List<_NavItem>? navItems}) {
    final ordersTabIndex = (navItems != null) ? navItems.indexWhere((i) => i.label == 'Заказы') : -1;
    final isOrdersTabSelected = ordersTabIndex >= 0 && currentTabIndex == ordersTabIndex;

    if (role == BusinessRole.master) {
      return const [MasterTasksScreen(), MasterScheduleScreen(), ProfileScreen()];
    }
    if (desktop && role == BusinessRole.owner) {
      return [
        const DashboardScreen(),
        const ScheduleScreen(),
        OrdersScreen(isTabSelected: isOrdersTabSelected),
        const CarsScreen(),
        const ChatsScreen(),
        const FinanceScreen(),
        const SettingsScreen(),
      ];
    }
    if (desktop && role == BusinessRole.admin) {
      return [
        const ScheduleScreen(),
        OrdersScreen(isTabSelected: isOrdersTabSelected),
        const CarsScreen(),
        const ChatsScreen(),
        const SettingsScreen(),
      ];
    }
    if (desktop && role == BusinessRole.solo) {
      return [
        const ScheduleScreen(),
        OrdersScreen(isTabSelected: isOrdersTabSelected),
        const CarsScreen(),
        const ChatsScreen(),
        const SettingsScreen(),
      ];
    }
    if (role == BusinessRole.owner) {
      return [
        const DashboardScreen(),
        const ScheduleScreen(),
        OrdersScreen(isTabSelected: isOrdersTabSelected),
        const ChatsScreen(),
        const ProfileScreen(),
      ];
    }
    return [
      const ScheduleScreen(),
      OrdersScreen(isTabSelected: isOrdersTabSelected),
      const ChatsScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).user?.role ?? BusinessRole.admin;
    final useDesktopLayout = isDesktopPlatform;
    final items = _itemsForRole(role, desktop: useDesktopLayout);
    final index = _currentIndex.clamp(0, items.length - 1);
    final screens = _screensForRole(role, desktop: useDesktopLayout, currentTabIndex: index, navItems: items);
    if (index != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentIndex = index);
      });
    }

    final isWide = MediaQuery.sizeOf(context).width >= _kBreakpointWide;

    if (useDesktopLayout) {
      return _buildDesktopLayout(context, role, items, screens, index);
    }

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: true,
              backgroundColor: AppColors.navBg,
              selectedIndex: index,
              onDestinationSelected: _onTabSelected,
              destinations: items
                  .map((item) => NavigationRailDestination(
                        icon: Icon(item.icon, color: AppColors.navInactive),
                        selectedIcon: Icon(item.icon, color: AppColors.navActive),
                        label: Text(item.label),
                      ))
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: IndexedStack(
                index: index,
                children: screens,
              ),
            ),
          ],
        ),
      );
    }

    final chatState = ref.watch(chatRepositoryProvider);
    final totalUnreadChats = chatState.chats.fold<int>(0, (s, c) => s + c.unreadCount);
    final showQuickOrderFab = items[index].label == 'Расписание' || items[index].label == 'Заказы';

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: screens,
      ),
      floatingActionButton: showQuickOrderFab
          ? FloatingActionButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const QuickCreateOrderScreen(),
                  fullscreenDialog: isDesktopPlatform,
                ),
              ),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.navBg,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (i) {
                final item = items[i];
                final isActive = i == index;
                final badgeCount = item.label == 'Чаты' ? totalUnreadChats : 0;
                return Expanded(
                  child: InkWell(
                    onTap: () => _onTabSelected(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              item.icon,
                              size: 26,
                              color: isActive ? AppColors.navActive : AppColors.navInactive,
                            ),
                            if (badgeCount > 0)
                              Positioned(
                                right: -6,
                                top: -2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.error,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                  child: Text(
                                    badgeCount > 99 ? '99+' : '$badgeCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: isActive ? AppColors.navActive : AppColors.navInactive,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    BusinessRole role,
    List<_NavItem> items,
    List<Widget> screens,
    int index,
  ) {
    final user = ref.watch(authProvider).user;
    final chatState = ref.watch(chatRepositoryProvider);
    final totalUnread = chatState.chats.fold<int>(0, (s, c) => s + c.unreadCount);

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): const _GlobalSearchIntent(),
        const SingleActivator(LogicalKeyboardKey.escape): const _ClosePanelIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _GlobalSearchIntent: CallbackAction<_GlobalSearchIntent>(
            onInvoke: (_) {
              _showGlobalSearch(context);
              return null;
            },
          ),
          _ClosePanelIntent: CallbackAction<_ClosePanelIntent>(
            onInvoke: (_) {
              ref.read(scheduleSelectedOrderIdProvider.notifier).state = null;
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: AppColorsDesktop.background,
            body: Row(
              children: [
                // Левый sidebar: логотип, навигация, профиль внизу
                Container(
                  width: DesktopDesignSystem.sidebarWidth,
                  decoration: BoxDecoration(
                    color: AppColorsDesktop.navBg,
                    border: const Border(right: BorderSide(color: AppColorsDesktop.border)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(1, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: DesktopDesignSystem.sidebarLogoHeight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: DesktopDesignSystem.sidebarItemPaddingH),
                          child: Row(
                            children: [
                              Icon(Icons.build_circle_rounded, color: AppColorsDesktop.primary, size: 24),
                              const SizedBox(width: 10),
                              Text('AutoHub', style: DesktopDesignSystem.sectionTitle.copyWith(fontSize: 15)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: DesktopDesignSystem.sidebarItemPaddingH - 4),
                          children: List.generate(items.length, (i) {
                            final item = items[i];
                            final selected = i == index;
                            final badge = item.label == 'Чаты' && totalUnread > 0 ? totalUnread : 0;
                            return _SidebarNavTile(
                              icon: item.icon,
                              label: item.label,
                              selected: selected,
                              badge: badge,
                              onTap: () => _onTabSelected(i),
                            );
                          }),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(DesktopDesignSystem.sidebarProfilePadding),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: AppColorsDesktop.border)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (user != null) ...[
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColorsDesktop.primary.withValues(alpha: 0.15),
                                    child: Text(
                                      user.initials,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColorsDesktop.primary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          user.displayName,
                                          style: DesktopDesignSystem.body.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(user.role.label, style: DesktopDesignSystem.meta),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (user.hasMultipleOrganizations) ...[
                                _DesktopOrgSwitch(onPressed: () => showOrganizationSwitchSheet(context, ref)),
                                const SizedBox(height: 8),
                              ],
                              OutlinedButton.icon(
                                onPressed: () => ref.read(authProvider.notifier).logout(),
                                icon: const Icon(Icons.logout_rounded, size: 18),
                                label: const Text('Выход'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColorsDesktop.textSecondary,
                                  side: BorderSide(color: AppColorsDesktop.border),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
          // Контент: вложенный Navigator, чтобы «Создать заказ» открывался только справа от меню
          Expanded(
            child: Navigator(
              key: _contentNavigatorKey,
              initialRoute: '/',
              onGenerateRoute: (RouteSettings settings) {
                if (settings.name == '/create-order') {
                  return MaterialPageRoute<void>(
                    builder: (_) => const QuickCreateOrderScreen(),
                  );
                }
                return MaterialPageRoute<void>(
                  builder: (_) => Stack(
                    children: [
                      Column(
                        children: [
                          if (!(index == 0 && role == BusinessRole.owner))
                            _DesktopTopBar(title: items[index].label),
                          Expanded(
                            child: IndexedStack(
                              index: index,
                              children: screens,
                            ),
                          ),
                        ],
                      ),
                      if ((items[index].label == 'Расписание' || items[index].label == 'Заказы'))
                        Positioned(
                          right: 24,
                          bottom: 24,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(14),
                            color: AppColorsDesktop.primary,
                            child: Tooltip(
                              message: 'Создать заказ',
                              child: InkWell(
                                onTap: () {
                                  _contentNavigatorKey.currentState?.push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const QuickCreateOrderScreen(),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.key_rounded, color: Colors.white, size: 28),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
    ),
    ),
    );
  }

  void _showGlobalSearch(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => _GlobalSearchOverlay(
        onClose: () => Navigator.of(ctx).pop(),
        onSelectOrder: (id) {
          Navigator.of(ctx).pop();
          ref.read(scheduleSelectedOrderIdProvider.notifier).state = id;
        },
      ),
    );
  }
}

class _GlobalSearchIntent extends Intent {
  const _GlobalSearchIntent();
}
class _ClosePanelIntent extends Intent {
  const _ClosePanelIntent();
}

class _GlobalSearchOverlay extends ConsumerStatefulWidget {
  const _GlobalSearchOverlay({required this.onClose, required this.onSelectOrder});

  final VoidCallback onClose;
  final void Function(String orderId) onSelectOrder;

  @override
  ConsumerState<_GlobalSearchOverlay> createState() => _GlobalSearchOverlayState();
}

class _GlobalSearchOverlayState extends ConsumerState<_GlobalSearchOverlay> {
  final _query = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      child: Center(
            child: Material(
              color: AppColorsDesktop.surface,
              borderRadius: BorderRadius.circular(12),
              elevation: 8,
              child: Container(
                width: 500,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.search_rounded, color: AppColorsDesktop.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _query,
                            focusNode: _focus,
                            decoration: const InputDecoration(
                              hintText: 'Поиск заказов, клиентов... (Ctrl+K)',
                              border: InputBorder.none,
                            ),
                            onSubmitted: (_) => widget.onClose(),
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: widget.onClose),
                      ],
                    ),
                    const Divider(height: 1),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Глобальный поиск. Введите номер заказа или имя клиента.',
                        style: TextStyle(fontSize: 13, color: AppColorsDesktop.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
  }
}

class _SidebarNavTile extends StatefulWidget {
  const _SidebarNavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  State<_SidebarNavTile> createState() => _SidebarNavTileState();
}

class _SidebarNavTileState extends State<_SidebarNavTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final bg = selected
        ? AppColorsDesktop.primary.withValues(alpha: 0.12)
        : (_hover ? AppColorsDesktop.navHover : null);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(DesktopDesignSystem.sidebarItemRadius),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesktopDesignSystem.sidebarItemPaddingH,
              vertical: DesktopDesignSystem.sidebarItemPaddingV,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(DesktopDesignSystem.sidebarItemRadius),
              border: selected
                  ? const Border(left: BorderSide(color: AppColorsDesktop.primary, width: 3))
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 22,
                  color: selected ? AppColorsDesktop.primary : AppColorsDesktop.navInactive,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? AppColorsDesktop.primary : AppColorsDesktop.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColorsDesktop.error,
                      borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusBadge),
                    ),
                    child: Text(
                      widget.badge > 99 ? '99+' : '${widget.badge}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: DesktopDesignSystem.topbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: DesktopDesignSystem.topbarPaddingH),
      decoration: BoxDecoration(
        color: AppColorsDesktop.surface,
        border: const Border(bottom: BorderSide(color: AppColorsDesktop.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(title, style: DesktopDesignSystem.pageTitle.copyWith(fontSize: 18)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 22),
            onPressed: () {},
            tooltip: 'Уведомления',
            style: IconButton.styleFrom(foregroundColor: AppColorsDesktop.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _DesktopOrgSwitch extends ConsumerWidget {
  const _DesktopOrgSwitch({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgAsync = ref.watch(organizationProvider);
    final name = orgAsync.valueOrNull?.name ?? 'Организация';
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColorsDesktop.primary,
        side: const BorderSide(color: AppColorsDesktop.border),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      child: Row(
        children: [
          const Icon(Icons.business_rounded, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name, overflow: TextOverflow.ellipsis, style: DesktopDesignSystem.meta),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
