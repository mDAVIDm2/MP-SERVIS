import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/internal_roles.dart';
import '../api/auth_api_service.dart';
import '../api/storage_provider.dart';
import '../api/api_client.dart';
import '../api/internal_api.dart';

enum AuthStatus { initial, unauthenticated, authenticating, authenticated }

class ControlCenterUser {
  final String id;
  final String email;
  final String name;
  final InternalRole role;

  const ControlCenterUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
  });
}

class AuthState {
  final AuthStatus status;
  final ControlCenterUser? user;
  final String? accessToken;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.accessToken,
  });
}

final storageProvider = Provider<ControlCenterStorage>((ref) => SecureControlCenterStorage());

final dioProvider = Provider<Dio>((ref) => createDio(ref.watch(storageProvider)));

final authApiServiceProvider = Provider<AuthApiService>((ref) {
  return AuthApiService(
    ref.watch(dioProvider),
    ref.watch(storageProvider),
  );
});

final internalApiProvider = Provider<InternalApi>((ref) => InternalApi(ref.watch(dioProvider)));

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(authApiServiceProvider),
    ref.watch(storageProvider),
  );
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._authApi, this._storage) : super(const AuthState());

  final AuthApiService _authApi;
  final ControlCenterStorage _storage;

  Future<void> initialize() async {
    final token = await _storage.getAccessToken();
    if (token == null || token.isEmpty) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    final me = await _authApi.getMe(token);
    if (me == null) {
      await _storage.clear();
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    state = AuthState(
      status: AuthStatus.authenticated,
      accessToken: token,
      user: ControlCenterUser(
        id: me['id'] as String? ?? '',
        email: me['email'] as String? ?? '',
        name: me['name'] as String? ?? '',
        role: InternalRole.fromString(me['role'] as String?),
      ),
    );
  }

  /// Успех — (true, null). Ошибка — (false, statusCode): 401 = неверные данные, 404 = сервер не найден, null = сеть/таймаут.
  Future<(bool, int?)> login(String email, String password) async {
    state = const AuthState(status: AuthStatus.authenticating);
    try {
      final result = await _authApi.login(email, password);
      if (!result.isSuccess) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return (false, result.statusCode);
      }
      final data = result.data!;
      final token = data['access_token'] as String?;
      final userData = data['user'] as Map<String, dynamic>?;
      if (token == null || userData == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return (false, 500);
      }
      await _storage.setAccessToken(token);
      state = AuthState(
        status: AuthStatus.authenticated,
        accessToken: token,
        user: ControlCenterUser(
          id: userData['id'] as String? ?? '',
          email: userData['email'] as String? ?? '',
          name: userData['name'] as String? ?? '',
          role: InternalRole.fromString(userData['role'] as String?),
        ),
      );
      return (true, null);
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return (false, null);
    }
  }

  Future<void> logout() async {
    await _storage.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
