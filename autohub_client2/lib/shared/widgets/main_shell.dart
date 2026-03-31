import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/l10n/l10n_scope.dart';
import '../../core/providers/app_providers.dart';
import '../../core/push/client_push_service.dart';
import '../../core/settings/client_notification_prefs_provider.dart';
import '../../core/navigation/shell_navigation_provider.dart';
import '../../features/garage/presentation/screens/garage_screen.dart';
import '../../features/services/presentation/screens/services_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/chats/presentation/screens/chats_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late final PageController _pageController;
  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());

  final List<Widget> _screens = const [
    GarageScreen(),
    ServicesScreen(),
    SearchScreen(),
    ChatsScreen(),
    ProfileScreen(),
  ]; // SearchScreen — не const: внутри применяется bootstrap фильтров услуг

  List<_NavItem> _navItems(BuildContext context) {
    final l10n = L10nScope.of(context);
    final unreadChats = ref.watch(totalUnreadChatsCountProvider);
    return [
      _NavItem(icon: Icons.directions_car_rounded, label: l10n.navGarage),
      _NavItem(icon: Icons.favorite_rounded, label: l10n.navServices),
      _NavItem(icon: Icons.search_rounded, label: l10n.navSearch),
      _NavItem(icon: Icons.chat_bubble_rounded, label: l10n.navChats, badgeCount: unreadChats),
      _NavItem(icon: Icons.person_rounded, label: l10n.navProfile),
    ];
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(clientNotificationPrefsProvider);
      ClientPushService.instance.ensureStarted(ref);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    if (index == _currentIndex) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      HapticFeedback.lightImpact();
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      setState(() => _currentIndex = index);
    }
  }

  Future<void> _openSearchTabWithServices(List<String> serviceIds) async {
    if (!_pageController.hasClients) return;
    await _pageController.animateToPage(
      2,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    ref.read(searchServiceFilterBootstrapProvider.notifier).state = List<String>.from(serviceIds);
    setState(() => _currentIndex = 2);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<String>?>(openSearchWithServicesProvider, (prev, next) {
      if (next == null) return;
      final ids = List<String>.from(next);
      ref.read(openSearchWithServicesProvider.notifier).state = null;
      _openSearchTabWithServices(ids);
    });

    ref.listen<int?>(shellTargetTabProvider, (prev, next) {
      if (next == null || next < 0 || next > 4) return;
      final i = next;
      ref.read(shellTargetTabProvider.notifier).state = null;
      _pageController.animateToPage(
        i,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
      setState(() => _currentIndex = i);
    });

    return Scaffold(
      extendBody: true,
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (int index) {
          if (index != _currentIndex) setState(() => _currentIndex = index);
        },
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.navBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: AppColors.strokeGold.withValues(alpha: 0.12), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 72,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_navItems(context).length, (i) {
                final item = _navItems(context)[i];
                final isActive = i == _currentIndex;
                return Expanded(
                  child: _NavBarItem(
                    icon: item.icon,
                    label: item.label,
                    isActive: isActive,
                    badgeCount: item.badgeCount,
                    onTap: () => _onTap(i),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final int badgeCount;
  const _NavItem({required this.icon, required this.label, this.badgeCount = 0});
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.gold1.withValues(alpha: 0.1),
        highlightColor: AppColors.gold1.withValues(alpha: 0.05),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(horizontal: isActive ? 16 : 0, vertical: 8),
                  decoration: isActive
                      ? BoxDecoration(
                          color: AppColors.gold1.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.strokeGold.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        )
                      : null,
                  child: Icon(
                    icon,
                    size: 26,
                    color: isActive ? AppColors.gold1 : AppColors.textMuted,
                  ),
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
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.error.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
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
            const SizedBox(height: 6),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? AppColors.gold1 : AppColors.textMuted,
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
