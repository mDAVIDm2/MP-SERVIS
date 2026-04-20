import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/screens/auth_screens.dart';
import '../../shared/widgets/main_shell.dart';
import '../theme/client_palette.dart';
import '../ws/ws_orders_listener.dart';
import 'app_lock_overlay.dart';
import 'app_lock_provider.dart';
import 'auth_provider.dart';
import 'security_settings.dart';

/// После серверной авторизации: при необходимости имя/телефон → основной shell. PIN по умолчанию выключен, включается в настройках безопасности.
class PostAuthShell extends ConsumerStatefulWidget {
  const PostAuthShell({super.key});

  @override
  ConsumerState<PostAuthShell> createState() => _PostAuthShellState();
}

class _PostAuthShellState extends ConsumerState<PostAuthShell> {
  bool _ready = false;
  bool _needsProfileBasics = false;
  bool _scheduledLaunchLock = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_bootstrap);
  }

  bool _userNeedsProfileBasics() {
    final u = ref.read(authProvider).user;
    if (u == null) return false;
    final noName = u.name.trim().isEmpty;
    final noPhone = u.phone == null || u.phone!.trim().isEmpty;
    return noName || noPhone;
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    final settings = ref.read(securitySettingsProvider);
    final justAuthorized = await ref.read(authProvider.notifier).consumeJustAuthorizedFlag();
    final needBasics = _userNeedsProfileBasics();
    setState(() {
      _needsProfileBasics = needBasics;
      _ready = true;
    });
    if (!needBasics) {
      _scheduleColdStartLock(settings.pinEnabled, settings.lockRequestMode, justAuthorized);
    }
  }

  /// При старте с уже сохранённым PIN — сразу показать экран разблокировки.
  void _scheduleColdStartLock(bool pinEnabled, LockRequestMode mode, bool justAuthorized) {
    if (!pinEnabled || _scheduledLaunchLock) return;
    final shouldLock = mode == LockRequestMode.appOpen || (mode == LockRequestMode.authorization && justAuthorized);
    if (!shouldLock) return;
    _scheduledLaunchLock = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(appLockProvider.notifier).lockNow();
    });
  }

  Future<void> _onProfileBasicsComplete() async {
    if (!mounted) return;
    setState(() => _needsProfileBasics = false);
    final settings = ref.read(securitySettingsProvider);
    _scheduleColdStartLock(
      settings.pinEnabled,
      settings.lockRequestMode,
      true,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      final p = context.palette;
      return Scaffold(
        backgroundColor: p.background,
        body: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2, color: p.primary),
          ),
        ),
      );
    }
    if (_needsProfileBasics) {
      return MandatoryProfileBasicsScreen(onComplete: _onProfileBasicsComplete);
    }
    return AppLockOverlay(
      child: WsOrdersListener(child: const MainShell()),
    );
  }
}
