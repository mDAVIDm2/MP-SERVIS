import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/auth/auth_provider.dart';
import '../../features/auth/presentation/screens/auth_screens.dart';
import '../../features/auth/presentation/screens/select_organization_screen.dart';
import '../../features/auth/presentation/screens/subscription_block_screen.dart';
import '../../features/profile/presentation/screens/incoming_invitations_screen.dart';
import '../../shared/widgets/main_shell.dart';

Widget _buildSplash() {
  return Scaffold(
    backgroundColor: AppColors.background,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'AutoHub Business',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Слушатель для перерасчёта redirect при смене auth.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this._ref) {
    _ref.listen<AuthState>(authProvider, (prev, next) => notifyListeners());
  }
  final Ref _ref;
}

GoRouter createAppRouter(Ref ref) {
  final refresh = _AuthRefresh(ref);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      final container = ProviderScope.containerOf(context);
      final auth = container.read(authProvider);
      final loc = state.uri.path;

      if (auth.status == AuthStatus.initial) {
        return null;
      }
      if (auth.subscriptionDeactivated) {
        if (loc == '/subscription-blocked') return null;
        return '/subscription-blocked';
      }
      if (auth.status != AuthStatus.authenticated) {
        if (loc == '/login') return null;
        if (loc == '/select-organization') return '/login';
        return '/login';
      }
      if (loc == '/login') {
        return '/app';
      }
      if (loc == '/select-organization') {
        return null;
      }
      if (loc == '/' || loc.isEmpty) {
        return '/app';
      }
      if (loc == '/subscription-blocked') return '/app';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => _buildSplash(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/select-organization',
        builder: (context, state) => const SelectOrganizationScreen(),
      ),
      GoRoute(
        path: '/subscription-blocked',
        builder: (context, state) => const SubscriptionBlockScreen(),
      ),
      GoRoute(
        path: '/invitations',
        builder: (context, state) => const IncomingInvitationsScreen(),
      ),
      GoRoute(
        path: '/app',
        builder: (context, state) {
          final tab = state.uri.queryParameters['tab'];
          final index = int.tryParse(tab ?? '0') ?? 0;
          return MainShell(key: ValueKey('shell-$index'), initialTabIndex: index);
        },
      ),
    ],
  );
}
