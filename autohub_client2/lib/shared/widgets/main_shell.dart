import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/client_palette.dart';
import '../../core/l10n/l10n_scope.dart';
import '../../core/providers/app_providers.dart';
import '../../core/push/client_push_service.dart';
import '../../core/settings/client_notification_prefs_provider.dart';
import '../../core/settings/filter_by_car_setting.dart';
import '../../core/settings/maintenance_reminders_provider.dart';
import '../../core/settings/mileage_prompt_storage.dart';
import '../../core/auth/auth_provider.dart' show authProvider, sharedPreferencesProvider, AuthState;
import '../../core/sync/client_app_state_sync.dart';
import '../../core/navigation/shell_navigation_provider.dart';
import '../../shared/models/car_model.dart';
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

class _MainShellState extends ConsumerState<MainShell> with WidgetsBindingObserver {
  static const int _tabCount = 5;

  late final PageController _pageController;
  int _currentIndex = 0;
  bool _mileagePromptOpen = false;

  /// Свайп между вкладками разрешён только если жест начался у края (см. [_kTabSwipeEdgeFraction]).
  bool _allowSwipeBetweenTabs = true;
  static const double _kTabSwipeEdgeFraction = 0.25;

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
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(clientNotificationPrefsProvider);
      ClientPushService.instance.ensureStarted(ref);
      final uid = ref.read(authProvider).user?.id;
      if (uid != null && uid.isNotEmpty) {
        unawaited(ref.read(clientAppStateSyncServiceProvider).pullAfterLogin());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  void _goToTab(int index) {
    if (index < 0 || index >= _tabCount) return;
    if (index == _currentIndex) return;
    HapticFeedback.lightImpact();
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildTabPageView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) {
            if (w <= 0) return;
            final x = e.localPosition.dx.clamp(0.0, w);
            final allow =
                x <= w * _kTabSwipeEdgeFraction || x >= w * (1.0 - _kTabSwipeEdgeFraction);
            if (allow != _allowSwipeBetweenTabs) {
              setState(() => _allowSwipeBetweenTabs = allow);
            }
          },
          child: PageView(
            controller: _pageController,
            physics: _allowSwipeBetweenTabs
                ? const BouncingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            onPageChanged: (i) {
              if (!mounted) return;
              if (i == _currentIndex) return;
              HapticFeedback.selectionClick();
              setState(() => _currentIndex = i);
            },
            children: const [
              GarageScreen(),
              ServicesScreen(),
              SearchScreen(),
              ChatsScreen(),
              ProfileScreen(),
            ],
          ),
        );
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _tryShowMileageUpdateDialog();
        unawaited(ref.read(authProvider.notifier).syncProfileWithServer());
        unawaited(ref.read(clientAppStateSyncServiceProvider).maybePullOnAppResume());
      });
    }
  }

  Future<void> _tryShowMileageUpdateDialog() async {
    if (_mileagePromptOpen || !mounted) return;
    final prefs = ref.read(sharedPreferencesProvider).valueOrNull;
    final uid = ref.read(authProvider).user?.id;
    if (prefs == null || uid == null) return;
    final cars = ref.read(carsProvider).valueOrNull;
    if (cars == null || cars.isEmpty) return;
    final sel = ref.read(selectedCarIdProvider);
    Car? car;
    if (sel != null) {
      for (final c in cars) {
        if (c.id == sel) {
          car = c;
          break;
        }
      }
    }
    car ??= cars.first;
    if (!MileagePromptStorage.shouldPrompt(prefs, uid, car.id)) return;

    _mileagePromptOpen = true;
    final controller = TextEditingController(text: car.mileage > 0 ? '${car.mileage}' : '');
    final carId = car.id;
    final carLabel = car.displayName;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final l10n = L10nScope.of(ctx);
        return AlertDialog(
          title: Text(l10n.mileagePromptTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.mileagePromptBody(carLabel),
                style: TextStyle(fontSize: 14, color: context.palette.textSecondary),
              ),
              SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.mileageKmFieldLabel,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.later),
            ),
            FilledButton(
              onPressed: () async {
                final raw = controller.text.replaceAll(' ', '').trim();
                final km = int.tryParse(raw);
                if (km == null || km < 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(l10n.enterValidMileage)),
                  );
                  return;
                }
                final ok = await ref.read(carsProvider.notifier).updateMileage(carId, km);
                if (!ctx.mounted) return;
                if (ok) {
                  Navigator.pop(ctx);
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(l10n.mileageSaveFailed)),
                  );
                }
              },
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (mounted) setState(() => _mileagePromptOpen = false);
  }

  void _onTap(int index) {
    if (index == _currentIndex) {
      return;
    }
    _goToTab(index);
  }

  Future<void> _openSearchTabWithServices(List<String> serviceIds) async {
    _goToTab(2);
    if (!mounted) return;
    ref.read(searchServiceFilterBootstrapProvider.notifier).state = List<String>.from(serviceIds);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (prev, next) {
      final nu = next.user?.id;
      final pu = prev?.user?.id;
      if (nu != null &&
          nu.isNotEmpty &&
          pu != null &&
          pu.isNotEmpty &&
          nu != pu) {
        unawaited(ref.read(clientAppStateSyncServiceProvider).pullAfterLogin());
      }
    });

    ref.listen<AsyncValue<List<Car>>>(carsProvider, (prev, next) {
      next.whenData((cars) {
        final prefs = ref.read(sharedPreferencesProvider).valueOrNull;
        final uid = ref.read(authProvider).user?.id;
        if (prefs == null || uid == null || cars.isEmpty) return;
        Future(() async {
          await MileagePromptStorage.migrateMissingForCars(prefs, uid, cars.map((c) => c.id));
          final notifier = ref.read(maintenanceRemindersProvider.notifier);
          for (final c in cars) {
            notifier.ensureStandardRemindersForCar(c.id);
          }
        });
      });
    });

    ref.listen<List<String>?>(openSearchWithServicesProvider, (prev, next) {
      if (next == null) return;
      final ids = List<String>.from(next);
      ref.read(openSearchWithServicesProvider.notifier).state = null;
      _openSearchTabWithServices(ids);
    });

    ref.listen<int?>(shellTargetTabProvider, (prev, next) {
      if (next == null || next < 0 || next >= _tabCount) return;
      final i = next;
      ref.read(shellTargetTabProvider.notifier).state = null;
      _goToTab(i);
    });

    return Scaffold(
      extendBody: true,
      body: _buildTabPageView(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.palette.navBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: context.palette.strokeGold.withValues(alpha: 0.12), width: 1),
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
        splashColor: context.palette.gold1.withValues(alpha: 0.1),
        highlightColor: context.palette.gold1.withValues(alpha: 0.05),
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
                          color: context.palette.gold1.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: context.palette.strokeGold.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        )
                      : null,
                  child: Icon(
                    icon,
                    size: 26,
                    color: isActive ? context.palette.gold1 : context.palette.textMuted,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.palette.error,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: context.palette.error.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: TextStyle(
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
            SizedBox(height: 6),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? context.palette.gold1 : context.palette.textMuted,
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
