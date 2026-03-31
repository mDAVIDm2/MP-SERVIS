import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) => createAppRouter(ref));
