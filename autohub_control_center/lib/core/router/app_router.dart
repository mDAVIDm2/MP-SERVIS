import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/organizations/organizations_screen.dart';
import '../../features/organizations/organization_detail_screen.dart';
import '../../features/users/users_screen.dart';
import '../../features/subscriptions/subscriptions_screen.dart';
import '../../features/car_dictionaries/car_dictionaries_screen.dart';
import '../../features/service_dictionaries/service_dictionaries_screen.dart';
import '../../features/orders/orders_screen.dart';
import '../../features/audit/audit_screen.dart';
import '../../features/client_cars/client_cars_screen.dart';
import '../../features/client_cars/client_car_history_screen.dart';
import '../../features/support/support_chats_screen.dart';
import '../../features/support/support_chat_detail_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    redirect: (context, state) {
      final path = state.matchedLocation;
      if (authState.status == AuthStatus.initial) return null;
      if (authState.status != AuthStatus.authenticated) {
        if (path == '/login') return null;
        return '/login';
      }
      if (path == '/login') return '/app';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(
          child: child,
          currentLocation: state.matchedLocation,
        ),
        routes: [
          GoRoute(
            path: '/app',
            builder: (context, state) => const DashboardScreen(),
            routes: [
              GoRoute(
              path: 'organizations',
              builder: (context, state) => const OrganizationsScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) {
                    final id = state.pathParameters['id'] ?? '';
                    return OrganizationDetailScreen(organizationId: id);
                  },
                ),
              ],
            ),
              GoRoute(path: 'users', builder: (context, state) => const UsersScreen()),
              GoRoute(path: 'subscriptions', builder: (context, state) => const SubscriptionsScreen()),
              GoRoute(path: 'car-dictionaries', builder: (context, state) => const CarDictionariesScreen()),
              GoRoute(path: 'service-dictionaries', builder: (context, state) => const ServiceDictionariesScreen()),
              GoRoute(path: 'orders', builder: (context, state) => const OrdersScreen()),
              GoRoute(
                path: 'client-cars',
                builder: (context, state) => const ClientCarsScreen(),
                routes: [
                  GoRoute(
                    path: 'history',
                    builder: (context, state) {
                      final phone = state.uri.queryParameters['phone'] ?? '';
                      final carId = state.uri.queryParameters['car_id'] ?? '';
                      return ClientCarHistoryScreen(clientPhone: phone, carId: carId);
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'support-chats',
                builder: (context, state) => const SupportChatsScreen(),
                routes: [
                  GoRoute(
                    path: ':chatId',
                    builder: (context, state) {
                      final id = state.pathParameters['chatId'] ?? '';
                      return SupportChatDetailScreen(chatId: id);
                    },
                  ),
                ],
              ),
              GoRoute(path: 'audit', builder: (context, state) => const AuditScreen()),
            ],
          ),
        ],
      ),
    ],
  );
});
