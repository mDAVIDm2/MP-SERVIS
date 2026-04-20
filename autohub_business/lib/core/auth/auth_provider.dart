import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/models/user_organization_summary.dart';
import '../config/app_config.dart';
import '../api/api_client.dart';
import '../api/api_exceptions.dart';
import '../api/services/api_services_providers.dart';
import '../api/services/auth_api_service.dart';
import '../ws/ws_client.dart';
import '../ws/ws_provider.dart';
import 'device_id_service.dart';

const _kAccessToken = 'auth_access_token';
const _kRefreshToken = 'auth_refresh_token';
const _kUserId = 'auth_user_id';
const _kUserPhone = 'auth_user_phone';
const _kUserEmail = 'auth_user_email';
const _kUserName = 'auth_user_name';
const _kUserRole = 'auth_user_role';
const _kOrganizationId = 'auth_organization_id';
const _kOrganizationsJson = 'auth_organizations_json';
const _kUserAvatarUrl = 'auth_user_avatar_url';
const _kDemoBusinessToken = 'demo_jwt_business';

/// Роль в приложении Business (как в Master Prompt).
enum BusinessRole {
  owner,
  admin,
  master,
  solo;

  String get label {
    switch (this) {
      case BusinessRole.owner:
        return 'Владелец';
      case BusinessRole.admin:
        return 'Администратор';
      case BusinessRole.master:
        return 'Мастер';
      case BusinessRole.solo:
        return 'Самозанятый';
    }
  }

  bool get canSeeDashboard => this == BusinessRole.owner;
  bool get canSeeOrders => true;
  bool get canSeeCalendar => true;
  bool get canSeeChats => this != BusinessRole.master;
  bool get canSeeClients => this != BusinessRole.master;
  bool get canSeeStaff => this == BusinessRole.owner || this == BusinessRole.admin;
  /// Управление персоналом и приглашениями: владелец, админ, самозанятый. У мастера — нет.
  bool get canInviteStaff => canSeeStaff || this == BusinessRole.solo;
  bool get canSeeSettings => true;
  bool get canAssignMaster => this == BusinessRole.owner || this == BusinessRole.admin;
  bool get canSeePrices => this != BusinessRole.master;
  bool get canSeeClientPhones => this != BusinessRole.master;

  static BusinessRole fromString(String? value) {
    if (value == null) return BusinessRole.solo;
    return BusinessRole.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => BusinessRole.solo,
    );
  }
}

enum AuthStatus { initial, unauthenticated, authenticating, authenticated }

/// Права из карточки персонала (master/admin) с сервера; у owner/solo не используются.
class StaffCapabilities {
  final bool canSeeChats;
  final bool canWriteChats;
  final bool canManageOrgSettings;

  const StaffCapabilities({
    required this.canSeeChats,
    required this.canWriteChats,
    required this.canManageOrgSettings,
  });

  static StaffCapabilities? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    return StaffCapabilities(
      canSeeChats: m['can_see_chats'] == true,
      canWriteChats: m['can_write_chats'] == true,
      canManageOrgSettings: m['can_manage_org_settings'] == true,
    );
  }
}

class AuthUser {
  final String id;
  final String phone;
  final String? email;
  final String name;
  final BusinessRole role;
  final String? organizationId;
  final List<UserOrganizationSummary> organizations;
  final bool emailVerified;
  final bool phoneVerified;
  final String? avatarUrl;
  final StaffCapabilities? staffCapabilities;

  const AuthUser({
    required this.id,
    required this.phone,
    this.email,
    required this.name,
    required this.role,
    this.organizationId,
    this.organizations = const [],
    this.emailVerified = true,
    this.phoneVerified = true,
    this.avatarUrl,
    this.staffCapabilities,
  });

  /// Вкладка «Чаты» (owner/solo — всегда да; master/admin — флаги персонала, иначе по умолчанию только admin).
  bool get effectiveCanSeeChats {
    if (role == BusinessRole.owner || role == BusinessRole.solo) return true;
    return staffCapabilities?.canSeeChats ?? (role == BusinessRole.admin);
  }

  bool get effectiveCanWriteChats {
    if (role == BusinessRole.owner || role == BusinessRole.solo) return true;
    return staffCapabilities?.canWriteChats ?? (role == BusinessRole.admin);
  }

  /// Услуги, слоты, рабочее время и т.д.
  bool get effectiveCanManageOrgSettings {
    if (role == BusinessRole.owner || role == BusinessRole.solo) return true;
    return staffCapabilities?.canManageOrgSettings ?? (role == BusinessRole.admin);
  }

  bool get hasMultipleOrganizations => organizations.length > 1;

  /// Организация для API: `organization_id` из профиля или первая запись в `organizations`, если поле не пришло.
  String? get effectiveOrganizationId {
    final id = organizationId?.trim();
    if (id != null && id.isNotEmpty) return id;
    for (final o in organizations) {
      final oid = o.id.trim();
      if (oid.isNotEmpty) return oid;
    }
    return null;
  }

  String get displayName => name;

  String get accountLabel => (email != null && email!.trim().isNotEmpty) ? email! : (phone.isNotEmpty ? phone : '—');
  String get initials => name.isNotEmpty ? name[0].toUpperCase() : '?';
}

class AuthState {
  final AuthStatus status;
  final AuthUser? user;
  final String? accessToken;
  final String? refreshToken;
  final bool subscriptionDeactivated;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.accessToken,
    this.refreshToken,
    this.subscriptionDeactivated = false,
  });
  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    String? accessToken,
    String? refreshToken,
    bool? subscriptionDeactivated,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      subscriptionDeactivated: subscriptionDeactivated ?? this.subscriptionDeactivated,
    );
  }
}

List<UserOrganizationSummary> _organizationsFromPrefsString(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => UserOrganizationSummary.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((o) => o.id.isNotEmpty)
        .toList();
  } catch (_) {
    return const [];
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;
  final SharedPreferences _prefs;
  final AuthApiService _authApi;
  final WsClient _wsClient;

  Future<String?>? _refreshInFlight;

  AuthNotifier(this._apiClient, this._prefs, this._authApi, this._wsClient) : super(const AuthState());

  Future<void> initialize() async {
    final done = await Future.any<bool>([
      _doInitialize(),
      Future.delayed(const Duration(milliseconds: 2500), () => false),
    ]);
    if (!done && mounted) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  void _scheduleProfileRefresh() {
    Future.microtask(() async {
      if (!mounted) return;
      final token = state.accessToken;
      if (token == null || token.isEmpty) return;
      final r = await _authApi.getProfile();
      final u = r.dataOrNull;
      if (u == null || !mounted) return;
      state = AuthState(
        status: AuthStatus.authenticated,
        user: u,
        accessToken: token,
        refreshToken: state.refreshToken ?? _prefs.getString(_kRefreshToken),
      );
      _persist(u, token);
    });
  }

  Future<bool> _doInitialize() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return true;
    final token = _prefs.getString(_kAccessToken);
    if (token == null || token.isEmpty) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return true;
    }
    final refresh = _prefs.getString(_kRefreshToken);
    final id = _prefs.getString(_kUserId);
    final phone = _prefs.getString(_kUserPhone) ?? '';
    final email = _prefs.getString(_kUserEmail);
    final name = _prefs.getString(_kUserName) ?? '';
    final role = BusinessRole.fromString(_prefs.getString(_kUserRole));
    final orgId = _prefs.getString(_kOrganizationId);
    final orgs = _organizationsFromPrefsString(_prefs.getString(_kOrganizationsJson));
    final hasContact = phone.isNotEmpty || (email != null && email.isNotEmpty);
    if (id != null && hasContact) {
      state = AuthState(
        status: AuthStatus.authenticated,
        user: AuthUser(
          id: id,
          phone: phone,
          email: email != null && email.isNotEmpty ? email : null,
          name: name,
          role: role,
          organizationId: orgId,
          organizations: orgs,
          emailVerified: true,
          phoneVerified: true,
          avatarUrl: _prefs.getString(_kUserAvatarUrl),
          staffCapabilities: null,
        ),
        accessToken: token,
        refreshToken: refresh,
      );
      _apiClient.setToken(token);
      _wsClient.accessToken = token;
      _wsClient.connect();
      _scheduleProfileRefresh();
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
    return true;
  }

  void _persist(
    AuthUser user,
    String token, {
    String? refreshToken,
    bool syncRefresh = false,
  }) {
    _prefs.setString(_kAccessToken, token);
    if (syncRefresh) {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        _prefs.setString(_kRefreshToken, refreshToken);
      } else {
        _prefs.remove(_kRefreshToken);
      }
    }
    _prefs.setString(_kUserId, user.id);
    _prefs.setString(_kUserPhone, user.phone);
    if (user.email != null && user.email!.trim().isNotEmpty) {
      _prefs.setString(_kUserEmail, user.email!.trim());
    } else {
      _prefs.remove(_kUserEmail);
    }
    _prefs.setString(_kUserName, user.name);
    _prefs.setString(_kUserRole, user.role.name);
    if (user.organizationId != null && user.organizationId!.isNotEmpty) {
      _prefs.setString(_kOrganizationId, user.organizationId!);
    } else {
      _prefs.remove(_kOrganizationId);
    }
    if (user.organizations.isNotEmpty) {
      _prefs.setString(
        _kOrganizationsJson,
        jsonEncode(user.organizations.map((e) => e.toJson()).toList()),
      );
    } else {
      _prefs.remove(_kOrganizationsJson);
    }
    if (user.avatarUrl != null && user.avatarUrl!.trim().isNotEmpty) {
      _prefs.setString(_kUserAvatarUrl, user.avatarUrl!.trim());
    } else {
      _prefs.remove(_kUserAvatarUrl);
    }
  }

  String _platformLabel() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'other';
  }

  Future<Result<SendCodeResult>> sendLoginCode(String email) async {
    state = state.copyWith(status: AuthStatus.authenticating);
    final result = await _authApi.sendLoginCode(email, channel: 'email');
    final data = result.dataOrNull;
    if (data != null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return Result.success(data);
    }
    state = state.copyWith(status: AuthStatus.unauthenticated);
    return Result.failure(result.errorOrNull!);
  }

  /// Обновление access по refresh (single-flight, для интерцептора Dio при 401).
  Future<String?> refreshSession() {
    final existing = _refreshInFlight;
    if (existing != null) return existing;
    final future = _refreshSessionOnce();
    _refreshInFlight = future;
    future.whenComplete(() {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
      }
    });
    return future;
  }

  Future<String?> _refreshSessionOnce() async {
    var refresh = state.refreshToken ?? _prefs.getString(_kRefreshToken);
    if (refresh == null || refresh.isEmpty || refresh == _kDemoBusinessToken) {
      return null;
    }
    final deviceId = await getOrCreateDeviceId(_prefs);
    final result = await _authApi.refresh(
      refresh,
      deviceId: deviceId,
      deviceName: 'MP-Servis Business',
      platform: _platformLabel(),
    );
    final verified = result.dataOrNull;
    if (verified == null) return null;
    if (!mounted) return null;
    state = AuthState(
      status: AuthStatus.authenticated,
      user: verified.user,
      accessToken: verified.token,
      refreshToken: verified.refreshToken ?? refresh,
      subscriptionDeactivated: state.subscriptionDeactivated,
    );
    _apiClient.setToken(verified.token);
    _wsClient.accessToken = verified.token;
    _wsClient.connect();
    _persist(
      verified.user,
      verified.token,
      refreshToken: verified.refreshToken,
      syncRefresh: true,
    );
    return verified.token;
  }

  Future<Result<AuthUser>> verifyEmailCode(
    String email,
    String challengeId,
    String code, {
    String? phoneUnverified,
    String? name,
  }) async {
    state = state.copyWith(status: AuthStatus.authenticating);
    final deviceId = await getOrCreateDeviceId(_prefs);
    final apiResult = await _authApi.verifyCode(
      email,
      challengeId,
      code,
      deviceId: deviceId,
      deviceName: 'MP-Servis Business',
      platform: _platformLabel(),
      phoneUnverified: phoneUnverified,
      name: name,
    );
    final verified = apiResult.dataOrNull;
    if (verified != null) {
      state = AuthState(
        status: AuthStatus.authenticated,
        user: verified.user,
        accessToken: verified.token,
        refreshToken: verified.refreshToken,
      );
      _apiClient.setToken(verified.token);
      _wsClient.accessToken = verified.token;
      _wsClient.connect();
      _persist(
        verified.user,
        verified.token,
        refreshToken: verified.refreshToken,
        syncRefresh: true,
      );
      return Result.success(verified.user);
    }
    state = state.copyWith(status: AuthStatus.unauthenticated);
    final err = apiResult.errorOrNull;
    return Result.failure(err ?? const ApiException(code: ApiErrorCode.validation, message: 'Неверный код'));
  }

  Future<Result<void>> switchOrganization(String organizationId) async {
    final token = state.accessToken;
    if (token == null || token.isEmpty) {
      return Result.failure(const ApiException(code: ApiErrorCode.unauthorized, message: 'Нет сессии'));
    }
    if (token == _kDemoBusinessToken) {
      final u = state.user;
      if (u == null) {
        return Result.failure(const ApiException(code: ApiErrorCode.unauthorized, message: 'Нет пользователя'));
      }
      UserOrganizationSummary? match;
      for (final o in u.organizations) {
        if (o.id == organizationId) {
          match = o;
          break;
        }
      }
      if (match == null) {
        return Result.failure(const ApiException(code: ApiErrorCode.validation, message: 'Организация не найдена'));
      }
      final next = AuthUser(
        id: u.id,
        phone: u.phone,
        email: u.email,
        name: u.name,
        role: BusinessRole.fromString(match.role),
        organizationId: match.id,
        organizations: u.organizations,
        emailVerified: u.emailVerified,
        phoneVerified: u.phoneVerified,
        avatarUrl: u.avatarUrl,
        staffCapabilities: u.staffCapabilities,
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        user: next,
        accessToken: token,
        refreshToken: state.refreshToken,
      );
      _persist(next, token);
      return Result.success(null);
    }
    final r = await _authApi.switchOrganization(organizationId);
    final v = r.dataOrNull;
    if (v == null) return Result.failure(r.errorOrNull ?? const ApiException(code: ApiErrorCode.internal, message: 'Ошибка смены организации'));
    state = AuthState(
      status: AuthStatus.authenticated,
      user: v.user,
      accessToken: token,
      refreshToken: state.refreshToken,
    );
    _persist(v.user, token);
    return Result.success(null);
  }

  Future<Result<void>> createAdditionalOrganization({
    required String name,
    String? address,
    String? phone,
  }) async {
    final token = state.accessToken;
    if (token == null || token.isEmpty) {
      return Result.failure(const ApiException(code: ApiErrorCode.unauthorized, message: 'Нет сессии'));
    }
    if (token == _kDemoBusinessToken) {
      final u = state.user;
      if (u == null) {
        return Result.failure(const ApiException(code: ApiErrorCode.unauthorized, message: 'Нет пользователя'));
      }
      final newId = 'demo_org_${DateTime.now().millisecondsSinceEpoch}';
      final newOrg = UserOrganizationSummary(id: newId, name: name, role: 'owner');
      final nextOrgs = [...u.organizations, newOrg];
      final nextRole = u.role == BusinessRole.solo ? BusinessRole.solo : BusinessRole.owner;
      final next = AuthUser(
        id: u.id,
        phone: u.phone,
        email: u.email,
        name: u.name,
        role: nextRole,
        organizationId: newId,
        organizations: nextOrgs,
        emailVerified: u.emailVerified,
        phoneVerified: u.phoneVerified,
        avatarUrl: u.avatarUrl,
        staffCapabilities: u.staffCapabilities,
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        user: next,
        accessToken: token,
        refreshToken: state.refreshToken,
      );
      _persist(next, token);
      return Result.success(null);
    }
    final r = await _authApi.createOwnedOrganization(name: name, address: address, phone: phone);
    final v = r.dataOrNull;
    if (v == null) {
      return Result.failure(r.errorOrNull ?? const ApiException(code: ApiErrorCode.internal, message: 'Не удалось создать организацию'));
    }
    state = AuthState(
      status: AuthStatus.authenticated,
      user: v.user,
      accessToken: token,
      refreshToken: state.refreshToken,
    );
    _persist(v.user, token);
    return Result.success(null);
  }

  Future<Result<void>> uploadProfileAvatarBytes(List<int> bytes, String filename) async {
    final token = state.accessToken;
    if (token == null || token.isEmpty) {
      return Result.failure(const ApiException(code: ApiErrorCode.unauthorized, message: 'Нет сессии'));
    }
    final r = await _authApi.uploadProfileAvatar(bytes: bytes, filename: filename);
    final u = r.dataOrNull;
    if (u == null) {
      return Result.failure(
        r.errorOrNull ?? const ApiException(code: ApiErrorCode.internal, message: 'Не удалось загрузить фото'),
      );
    }
    final bustedAvatar = _avatarUrlWithCacheBust(u.avatarUrl);
    final user = AuthUser(
      id: u.id,
      phone: u.phone,
      email: u.email,
      name: u.name,
      role: u.role,
      organizationId: u.organizationId,
      organizations: u.organizations,
      emailVerified: u.emailVerified,
      phoneVerified: u.phoneVerified,
      avatarUrl: bustedAvatar,
      staffCapabilities: u.staffCapabilities,
    );
    state = AuthState(
      status: AuthStatus.authenticated,
      user: user,
      accessToken: token,
      refreshToken: state.refreshToken,
      subscriptionDeactivated: state.subscriptionDeactivated,
    );
    _persist(user, token);
    return Result.success(null);
  }

  String? _avatarUrlWithCacheBust(String? url) {
    final base = AppConfig.resolveApiMediaUrl(url) ?? url;
    if (base == null || base.isEmpty) return base;
    final uri = Uri.parse(base);
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      't': DateTime.now().millisecondsSinceEpoch.toString(),
    }).toString();
  }

  Future<Result<void>> deleteAccount() async {
    final token = state.accessToken;
    if (token == null || token.isEmpty) {
      return Result.failure(const ApiException(code: ApiErrorCode.unauthorized, message: 'Нет сессии'));
    }
    if (token == _kDemoBusinessToken) {
      return Result.failure(const ApiException(code: ApiErrorCode.validation, message: 'В демо-режиме удаление недоступно'));
    }
    final r = await _authApi.deleteAccount();
    final err = r.errorOrNull;
    if (err != null) return Result.failure(err);
    await logout();
    return Result.success(null);
  }

  Future<Result<void>> refreshProfile() async {
    final token = state.accessToken;
    if (token == null || token.isEmpty) {
      return Result.failure(const ApiException(code: ApiErrorCode.unauthorized, message: 'Нет сессии'));
    }
    final r = await _authApi.getProfile();
    final u = r.dataOrNull;
    if (u == null) {
      return Result.failure(r.errorOrNull ?? const ApiException(code: ApiErrorCode.internal, message: 'Не удалось обновить профиль'));
    }
    state = AuthState(
      status: AuthStatus.authenticated,
      user: u,
      accessToken: token,
      refreshToken: state.refreshToken,
      subscriptionDeactivated: state.subscriptionDeactivated,
    );
    _persist(u, token);
    return Result.success(null);
  }

  void setSubscriptionDeactivated() {
    _wsClient.disconnect();
    _wsClient.accessToken = null;
    _apiClient.setToken(null);
    _prefs.remove(_kAccessToken);
    _prefs.remove(_kRefreshToken);
    _prefs.remove(_kUserId);
    _prefs.remove(_kUserPhone);
    _prefs.remove(_kUserEmail);
    _prefs.remove(_kUserName);
    _prefs.remove(_kUserRole);
    _prefs.remove(_kOrganizationId);
    _prefs.remove(_kOrganizationsJson);
    _prefs.remove(_kUserAvatarUrl);
    state = const AuthState(status: AuthStatus.unauthenticated, subscriptionDeactivated: true);
  }

  /// Локальный сброс сессии при 401 от API (без вызова logout на сервер, чтобы не зациклиться на том же 401).
  Future<void> forceLogoutUnauthorized() async {
    _wsClient.disconnect();
    _wsClient.accessToken = null;
    _apiClient.setToken(null);
    await _prefs.remove(_kAccessToken);
    await _prefs.remove(_kRefreshToken);
    await _prefs.remove(_kUserId);
    await _prefs.remove(_kUserPhone);
    await _prefs.remove(_kUserEmail);
    await _prefs.remove(_kUserName);
    await _prefs.remove(_kUserRole);
    await _prefs.remove(_kOrganizationId);
    await _prefs.remove(_kOrganizationsJson);
    await _prefs.remove(_kUserAvatarUrl);
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      subscriptionDeactivated: false,
    );
  }

  Future<void> logout() async {
    final refresh = state.refreshToken ?? _prefs.getString(_kRefreshToken);
    if (refresh != null && refresh.isNotEmpty && refresh != _kDemoBusinessToken) {
      await _authApi.logout(refresh);
    }
    _wsClient.disconnect();
    _wsClient.accessToken = null;
    _apiClient.setToken(null);
    await _prefs.remove(_kAccessToken);
    await _prefs.remove(_kRefreshToken);
    await _prefs.remove(_kUserId);
    await _prefs.remove(_kUserPhone);
    await _prefs.remove(_kUserEmail);
    await _prefs.remove(_kUserName);
    await _prefs.remove(_kUserRole);
    await _prefs.remove(_kOrganizationId);
    await _prefs.remove(_kOrganizationsJson);
    await _prefs.remove(_kUserAvatarUrl);
    state = const AuthState(status: AuthStatus.unauthenticated, subscriptionDeactivated: false);
  }
}

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) => SharedPreferences.getInstance());

final StateNotifierProvider<AuthNotifier, AuthState> authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  final authApi = ref.watch(authApiServiceProvider);
  final wsClient = ref.watch(wsClientProvider);
  final notifier = AuthNotifier(apiClient, prefs ?? _NoOpPrefs(), authApi, wsClient);
  apiClient.refreshTokenCallback = () => notifier.refreshSession();
  apiClient.onUnauthorized = () {
    notifier.forceLogoutUnauthorized();
  };
  apiClient.onSubscriptionDeactivated = () {
    notifier.setSubscriptionDeactivated();
  };
  return notifier;
});

class _NoOpPrefs implements SharedPreferences {
  Set<String> get keys => {};
  @override
  Object? get(String key) => null;
  @override
  bool? getBool(String key) => null;
  @override
  int? getInt(String key) => null;
  @override
  double? getDouble(String key) => null;
  @override
  String? getString(String key) => null;
  @override
  List<String>? getStringList(String key) => null;
  @override
  Future<bool> setString(String key, String value) async => false;
  @override
  Future<bool> remove(String key) async => false;
  @override
  Future<bool> clear() async => false;
  @override
  Set<String> getKeys() => {};
  @override
  bool containsKey(String key) => false;
  @override
  Future<bool> setBool(String key, bool value) async => false;
  @override
  Future<bool> setInt(String key, int value) async => false;
  @override
  Future<bool> setDouble(String key, double value) async => false;
  @override
  Future<bool> setStringList(String key, List<String> value) async => false;
  @override
  Future<bool> commit() async => false;
  @override
  Future<bool> reload() async => false;
}
