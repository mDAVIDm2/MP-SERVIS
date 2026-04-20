import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/auth/auth_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MpServisControlCenterApp(),
    ),
  );
}

class MpServisControlCenterApp extends ConsumerStatefulWidget {
  const MpServisControlCenterApp({super.key});

  @override
  ConsumerState<MpServisControlCenterApp> createState() => _MpServisControlCenterAppState();
}

class _MpServisControlCenterAppState extends ConsumerState<MpServisControlCenterApp> {
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
      title: 'MP-Servis Control Center',
      theme: AppTheme.light,
      routerConfig: ref.watch(goRouterProvider),
    );
  }
}
