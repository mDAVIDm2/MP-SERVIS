import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/auth/auth_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(
    const ProviderScope(
      child: AutoHubControlCenterApp(),
    ),
  );
}

class AutoHubControlCenterApp extends ConsumerStatefulWidget {
  const AutoHubControlCenterApp({super.key});

  @override
  ConsumerState<AutoHubControlCenterApp> createState() => _AutoHubControlCenterAppState();
}

class _AutoHubControlCenterAppState extends ConsumerState<AutoHubControlCenterApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'AutoHub Control Center',
      theme: AppTheme.light,
      routerConfig: ref.watch(goRouterProvider),
    );
  }
}
