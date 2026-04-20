import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/api_exceptions.dart';
import '../api/auth_api_service.dart';
import '../api/sessions_api_service.dart';
import 'device_id_service.dart';
import 'pin_vault.dart';
import 'security_settings.dart';
import 'token_storage.dart';

const _kAccessToken = 'auth_access_token';
const _kRefreshToken = 'auth_refresh_token';
const _kUserId = 'auth_user_id';
const _kUserPhone = 'auth_user_phone';
const _kUserEmail = 'auth_user_email';
const _kUserName = 'auth_user_name';
const _kUserSurname = 'auth_user_surname';
const _kUserAvatar = 'auth_user_avatar_url';
const _kJustAuthorized = 'auth_just_authorized';

/// Состояние авторизации
enum AuthStatus {
  initial,
  unauthenticated,
  authenticating,
  authenticated,
}

class AuthUser {
  final String id;
  final String? phone;
  final String name;
  final String? surname;
  final String? avatarUrl;
  final String? email;
  final String? city;

  const AuthUser({
    required this.id,
    this.phone,
    required this.name,
    this.surname,
    this.avatarUrl,
    this.email,
    this.city,
  });

  /// Для шапки профиля: email или телефон.
  String get accountLabel => (email != null && email!.trim().isNotEmpty) ? email! : (phone ?? '—');

  String get displayName => surname != null ? '$name $surname' : name;
  String get initials {
    final parts = displayName.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class AuthState {
  final AuthStatus status;
  final AuthUser? user;
  final String? accessToken;
  final String? refreshToken;
  final String? sessionId;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.accessToken,
    this.refreshToken,
    this.sessionId,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    String? accessToken,
    String? refreshToken,
    String? sessionId,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      sessionId: sessionId ?? this.sessionId,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._apiClient, this._authApi, this._prefs) : super(const AuthState());

  final ApiClient _apiClient;
  final AuthApiService _authApi;
  final SharedPreferences _prefs;
  final TokenStorage _tokenStorage = TokenStorage();

  /// Один общий refresh на все параллельные 401 — иначе каждый запрос шлёт старый refresh после ротации
  /// и бэкенд пишет `refresh_reuse_detected` (десятки push «Безопасность»).
  Future<String?>? _refreshInFlight;

  /// После успешного входа в уже существующий аккаунт — не показывать обязательный экран PIN.
  bool _skipMandatoryPinAfterAuth = false;

  Future<void> initialize([SharedPreferences? prefsOverride]) async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      final prefs = prefsOverride ?? _prefs;

      var stored = await _tokenStorage.readAll();
      var token = stored.access;
      var refresh = stored.refresh;
      var sessionId = stored.sessionId;

      if (token == null || token.isEmpty) {
        final legacyA = prefs.getString(_kAccessToken);
        final legacyR = prefs.getString(_kRefreshToken);
        if (legacyA != null && legacyA.isNotEmpty) {
          token = legacyA;
          refresh = legacyR ?? '';
          sessionId = sessionId ?? '';
          await _tokenStorage.writeAll(
            accessToken: token,
            refreshToken: refresh,
            sessionId: sessionId,
          );
          await prefs.remove(_kAccessToken);
          await prefs.remove(_kRefreshToken);
        }
      }

      if (token == null || token.isEmpty) {
        await prefs.setBool(_kJustAuthorized, false);
        if (mounted) state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }

      final id = prefs.getString(_kUserId);
      final phone = prefs.getString(_kUserPhone);
      final email = prefs.getString(_kUserEmail);
      final name = prefs.getString(_kUserName) ?? '';
      final surname = prefs.getString(_kUserSurname);
      final avatarUrl = prefs.getString(_kUserAvatar);
      if (!mounted) return;
      final hasContact = (email != null && email.isNotEmpty) || (phone != null && phone.isNotEmpty);
      if (id != null && hasContact) {
        await prefs.setBool(_kJustAuthorized, false);
        state = AuthState(
          status: AuthStatus.authenticated,
          user: AuthUser(
            id: id,
            phone: phone != null && phone.isNotEmpty ? phone : null,
            name: name,
            surname: surname,
            avatarUrl: avatarUrl != null && avatarUrl.isNotEmpty ? avatarUrl : null,
            email: email != null && email.isNotEmpty ? email : null,
          ),
          accessToken: token,
          refreshToken: refresh,
          sessionId: sessionId,
        );
        _apiClient.setToken(token);
        await syncProfileWithServer();
      } else {
        await prefs.setBool(_kJustAuthorized, false);
        if (mounted) state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } catch (_) {
      if (mounted) state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// Подтянуть с сервера актуальный профиль (аватар, имя, телефон) и сохранить локально.
  /// Нужен после переустановки приложения: токен в secure storage, а avatar_url только на сервере.
  Future<void> syncProfileWithServer() async {
    if (state.status != AuthStatus.authenticated ||
        state.accessToken == null ||
        state.accessToken!.isEmpty) {
      return;
    }
    final u = state.user;
    if (u == null) return;
    try {
      final res = await _apiClient.get<Map<String, dynamic>>(ApiEndpoints.profile);
      final data = res.data;
      if (data == null || !mounted) return;
      final avatarRaw = data['avatar_url']?.toString().trim();
      final nameRaw = data['name']?.toString().trim();
      final phoneRaw = data['phone']?.toString().trim();
      final emailRaw = data['email']?.toString().trim();
      final next = AuthUser(
        id: u.id,
        phone: (phoneRaw != null && phoneRaw.isNotEmpty) ? phoneRaw : u.phone,
        name: (nameRaw != null && nameRaw.isNotEmpty) ? nameRaw : u.name,
        surname: u.surname,
        avatarUrl: (avatarRaw != null && avatarRaw.isNotEmpty) ? avatarRaw : u.avatarUrl,
        email: (emailRaw != null && emailRaw.isNotEmpty) ? emailRaw : u.email,
        city: u.city,
      );
      if (!mounted) return;
      state = state.copyWith(user: next);
      await _persistSecureAndUser(
        next,
        state.accessToken!,
        state.refreshToken,
        state.sessionId,
      );
    } catch (_) {
      // офлайн / 401 — оставляем кэш из prefs
    }
  }

  Future<void> _persistSecureAndUser(
    AuthUser user,
    String accessToken,
    String? refreshToken,
    String? sessionId,
  ) async {
    await _tokenStorage.writeAll(
      accessToken: accessToken,
      refreshToken: refreshToken ?? '',
      sessionId: sessionId ?? '',
    );
    _prefs.setString(_kUserId, user.id);
    if (user.phone != null && user.phone!.isNotEmpty) {
      _prefs.setString(_kUserPhone, user.phone!);
    } else {
      await _prefs.remove(_kUserPhone);
    }
    if (user.email != null && user.email!.isNotEmpty) {
      _prefs.setString(_kUserEmail, user.email!);
    } else {
      await _prefs.remove(_kUserEmail);
    }
    _prefs.setString(_kUserName, user.name);
    if (user.surname != null) {
      _prefs.setString(_kUserSurname, user.surname!);
    } else {
      await _prefs.remove(_kUserSurname);
    }
    if (user.avatarUrl != null && user.avatarUrl!.trim().isNotEmpty) {
      _prefs.setString(_kUserAvatar, user.avatarUrl!.trim());
    } else {
      await _prefs.remove(_kUserAvatar);
    }
  }

  Future<String> _deviceId() => getOrCreateDeviceId(_prefs);

  String _platformLabel() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'other';
  }

  /// Отправка кода на email (доставка: console | email по настройке сервера).
  Future<Result<SendCodeResult>> sendLoginCode(String email) async {
    state = state.copyWith(status: AuthStatus.authenticating);
    final result = await _authApi.sendLoginCode(email, channel: 'email');
    if (result.dataOrNull != null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return Result.success(result.dataOrNull!);
    }
    state = state.copyWith(status: AuthStatus.unauthenticated);
    return Result.failure(result.errorOrNull!);
  }

  /// [existingAccountLogin]: true — вход по email в существующий аккаунт (send-code вернул account_exists).
  Future<Result<AuthUser>> verifyEmailCode(
    String email,
    String challengeId,
    String code, {
    String? phoneUnverified,
    String? name,
    bool existingAccountLogin = false,
  }) async {
    state = state.copyWith(status: AuthStatus.authenticating);
    final deviceId = await _deviceId();
    final result = await _authApi.verifyCode(
      email,
      challengeId,
      code,
      deviceId: deviceId,
      deviceName: 'MP-Servis Client',
      platform: _platformLabel(),
      phoneUnverified: phoneUnverified,
      name: name,
    );
    final data = result.dataOrNull;
    if (data != null) {
      final user = AuthUser(
        id: data.userId,
        phone: data.phone,
        name: data.name,
        surname: null,
        email: data.email,
      );
      if (existingAccountLogin) {
        _skipMandatoryPinAfterAuth = true;
      }
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        accessToken: data.accessToken,
        refreshToken: data.refreshToken,
        sessionId: data.sessionId,
      );
      _apiClient.setToken(data.accessToken);
      await _prefs.setBool(_kJustAuthorized, true);
      await _persistSecureAndUser(user, data.accessToken, data.refreshToken, data.sessionId);
      await syncProfileWithServer();
      return Result.success(state.user ?? user);
    }
    state = state.copyWith(status: AuthStatus.unauthenticated);
    return Result.failure(result.errorOrNull!);
  }

  /// После PATCH /profile — синхронизировать локальное состояние и SharedPreferences.
  void applyServerProfileFields({String? name, String? phone}) {
    final u = state.user;
    if (u == null) return;
    final nextName = name != null && name.trim().isNotEmpty ? name.trim() : u.name;
    final nextPhone = phone != null && phone.trim().isNotEmpty ? phone.trim() : u.phone;
    state = state.copyWith(
      user: AuthUser(
        id: u.id,
        phone: nextPhone,
        name: nextName,
        surname: u.surname,
        avatarUrl: u.avatarUrl,
        email: u.email,
        city: u.city,
      ),
    );
    _prefs.setString(_kUserName, nextName);
    if (nextPhone != null && nextPhone.isNotEmpty) {
      _prefs.setString(_kUserPhone, nextPhone);
    } else {
      _prefs.remove(_kUserPhone);
    }
  }

  /// Загрузка фото профиля (multipart, поле `file`). Обновляет [AuthUser.avatarUrl].
  Future<Result<String>> uploadAvatar({String? filePath, List<int>? bytes, String? filename}) async {
    if (state.user == null || state.accessToken == null || state.accessToken!.isEmpty) {
      return Result.failure(const ApiException(code: ApiErrorCode.unauthorized, message: 'Нет сессии'));
    }
    try {
      late final MultipartFile part;
      if (kIsWeb) {
        if (bytes == null || bytes.isEmpty) {
          return Result.failure(const ApiException(code: ApiErrorCode.validation, message: 'Нет данных изображения'));
        }
        final name = (filename == null || filename.isEmpty) ? 'avatar.jpg' : filename;
        part = MultipartFile.fromBytes(bytes, filename: name);
      } else {
        final path = filePath?.trim() ?? '';
        if (path.isEmpty) {
          return Result.failure(const ApiException(code: ApiErrorCode.validation, message: 'Не выбран файл'));
        }
        part = await MultipartFile.fromFile(path, filename: filename ?? path.split(Platform.pathSeparator).last);
      }
      final form = FormData.fromMap({'file': part});
      final res = await _apiClient.upload<Map<String, dynamic>>(ApiEndpoints.profileAvatar, formData: form);
      final data = res.data;
      final raw = data?['avatar_url']?.toString().trim();
      if (raw == null || raw.isEmpty) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Сервер не вернул ссылку на аватар'));
      }
      final u = state.user!;
      final next = AuthUser(
        id: u.id,
        phone: u.phone,
        name: u.name,
        surname: u.surname,
        avatarUrl: raw,
        email: u.email,
        city: u.city,
      );
      state = state.copyWith(user: next);
      await _prefs.setString(_kUserAvatar, raw);
      return Result.success(raw);
    } on DioException catch (e) {
      final msg = e.error is ApiException ? (e.error as ApiException).message : e.message;
      return Result.failure(ApiException(code: ApiErrorCode.internal, message: msg ?? 'Ошибка загрузки'));
    } catch (e) {
      return Result.failure(ApiException(code: ApiErrorCode.internal, message: '$e'));
    }
  }

  Future<Result<AuthUser>> updateProfile({
    String? name,
    String? surname,
    String? email,
    String? city,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final updated = AuthUser(
      id: state.user!.id,
      phone: state.user?.phone,
      name: name ?? state.user!.name,
      surname: surname ?? state.user?.surname,
      email: email ?? state.user?.email,
      city: city ?? state.user?.city,
      avatarUrl: state.user?.avatarUrl,
    );
    state = state.copyWith(user: updated);
    if (name != null) _prefs.setString(_kUserName, name);
    if (surname != null) _prefs.setString(_kUserSurname, surname);
    return Result.success(updated);
  }

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
    var refresh = state.refreshToken;
    if (refresh == null || refresh.isEmpty) {
      final s = await _tokenStorage.readAll();
      refresh = s.refresh;
    }
    if (refresh == null || refresh.isEmpty) return null;

    final deviceId = await _deviceId();
    final result = await _authApi.refresh(
      refresh,
      deviceId: deviceId,
      deviceName: 'MP-Servis Client',
      platform: _platformLabel(),
    );
    final data = result.dataOrNull;
    if (data == null) return null;
    if (!mounted) return null;

    final prev = state.user;
    final mergedUser = prev != null
        ? AuthUser(
            id: prev.id,
            phone: data.phone ?? prev.phone,
            name: data.name.isNotEmpty ? data.name : prev.name,
            surname: prev.surname,
            avatarUrl: prev.avatarUrl,
            email: data.email ?? prev.email,
            city: prev.city,
          )
        : prev;
    state = state.copyWith(
      accessToken: data.accessToken,
      refreshToken: data.refreshToken ?? refresh,
      sessionId: data.sessionId ?? state.sessionId,
      user: mergedUser ?? prev,
    );
    _apiClient.setToken(data.accessToken);
    if (state.user != null) {
      await _persistSecureAndUser(
        state.user!,
        data.accessToken,
        data.refreshToken ?? refresh,
        data.sessionId ?? state.sessionId,
      );
    }
    return data.accessToken;
  }

  Future<void> logout() async {
    final stored = await _tokenStorage.readAll();
    final refresh = stored.refresh ?? state.refreshToken;
    if (refresh != null && refresh.isNotEmpty) {
      await _authApi.logout(refresh);
    }
    _apiClient.setToken(null);
    await _tokenStorage.clear();
    await PinVault().clear();
    final sec = SecuritySettings(_prefs);
    await sec.setPinEnabled(false);
    await sec.setBiometricEnabled(false);
    await _prefs.remove(_kUserId);
    await _prefs.remove(_kUserPhone);
    await _prefs.remove(_kUserEmail);
    await _prefs.remove(_kUserName);
    await _prefs.remove(_kUserSurname);
    await _prefs.remove(_kUserAvatar);
    await _prefs.remove(_kAccessToken);
    await _prefs.remove(_kRefreshToken);
    await _prefs.setBool(_kJustAuthorized, false);
    _skipMandatoryPinAfterAuth = false;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<bool> consumeJustAuthorizedFlag() async {
    final v = _prefs.getBool(_kJustAuthorized) ?? false;
    if (v) {
      await _prefs.setBool(_kJustAuthorized, false);
    }
    return v;
  }

  /// Одноразово: вернуть и сбросить флаг «не требовать обязательный PIN после входа».
  bool takeSkipMandatoryPinAfterAuth() {
    final v = _skipMandatoryPinAfterAuth;
    _skipMandatoryPinAfterAuth = false;
    return v;
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

final authApiServiceProvider = Provider<AuthApiService>((ref) {
  return AuthApiService(ref.watch(apiClientProvider));
});

final sessionsApiServiceProvider = Provider<SessionsApiService>((ref) {
  return SessionsApiService(ref.watch(apiClientProvider));
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final authApi = ref.watch(authApiServiceProvider);
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  final notifier = AuthNotifier(apiClient, authApi, prefs ?? _NoOpPrefs());
  apiClient.refreshTokenCallback = () => notifier.refreshSession();
  return notifier;
});

class _NoOpPrefs implements SharedPreferences {
  @override
  Set<String> getKeys() => {};
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
  bool containsKey(String key) => false;
  @override
  List<String>? getStringList(String key) => null;
  @override
  Future<bool> setBool(String key, bool value) async => false;
  @override
  Future<bool> setInt(String key, int value) async => false;
  @override
  Future<bool> setDouble(String key, double value) async => false;
  @override
  Future<bool> setString(String key, String value) async => false;
  @override
  Future<bool> setStringList(String key, List<String> value) async => false;
  @override
  Future<bool> remove(String key) async => false;
  @override
  Future<bool> clear() async => false;
  @override
  Future<bool> commit() async => false;
  @override
  Future<bool> reload() async => false;
}
