import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/models/organization_model.dart';
import '../../shared/models/organization_business_kind.dart';
import '../../shared/models/organization_working_hours_week.dart';
import '../api/api_exceptions.dart';
import '../api/services/api_services_providers.dart';
import '../api/services/organization_api_service.dart';
import '../auth/auth_provider.dart';

const _kOrgNamePrefix = 'org_name_';
const _kOrgAddressPrefix = 'org_address_';
const _kOrgPhonePrefix = 'org_phone_';
const _kOrgHoursPrefix = 'org_hours_';
const _kOrgWeekPrefix = 'org_week_';
const _kOrgKindPrefix = 'org_business_kind_';
const _kOrgSchedulingModePrefix = 'org_scheduling_mode_';

final sharedPreferencesOrgProvider = FutureProvider<SharedPreferences>((ref) => SharedPreferences.getInstance());

/// Репозиторий организации: загрузка с API (GET), сохранение через API (PATCH) + кэш в prefs.
class OrganizationRepository extends StateNotifier<AsyncValue<OrganizationInfo>> {
  OrganizationRepository(this._api, this._prefs, this._ref) : super(const AsyncValue.loading()) {
    final orgId = _ref.read(authProvider).user?.effectiveOrganizationId;
    load(orgId);
    _ref.listen<AuthState>(authProvider, (prev, next) {
      final nextId = next.user?.effectiveOrganizationId;
      if (nextId != _orgId) load(nextId);
    });
  }

  final OrganizationApiService _api;
  final SharedPreferences _prefs;
  final Ref _ref;
  String? _orgId;

  OrganizationInfo _loadFromPrefs(String? orgId) {
    if (orgId == null || orgId.isEmpty) {
      return const OrganizationInfo(name: '', address: '', phone: '', workingHours: '');
    }
    return OrganizationInfo(
      name: _prefs.getString(_kOrgNamePrefix + orgId) ?? 'Мой автосервис',
      address: _prefs.getString(_kOrgAddressPrefix + orgId) ?? '',
      phone: _prefs.getString(_kOrgPhonePrefix + orgId) ?? '',
      workingHours: _prefs.getString(_kOrgHoursPrefix + orgId) ?? 'Пн–Пт 9:00–19:00, Сб 10:00–16:00',
      workingHoursWeek: OrganizationWorkingHoursWeek.weekFromPrefsJson(
        _prefs.getString(_kOrgWeekPrefix + orgId),
      ),
      businessKind: OrganizationBusinessKindCodes.normalize(_prefs.getString(_kOrgKindPrefix + orgId)),
      schedulingMode: _prefs.getString(_kOrgSchedulingModePrefix + orgId) ?? 'staff_based',
    );
  }

  Future<void> _saveToPrefs(OrganizationInfo org) async {
    final orgId = _orgId;
    if (orgId == null || orgId.isEmpty) return;
    await _prefs.setString(_kOrgNamePrefix + orgId, org.name);
    await _prefs.setString(_kOrgAddressPrefix + orgId, org.address);
    await _prefs.setString(_kOrgPhonePrefix + orgId, org.phone);
    await _prefs.setString(_kOrgHoursPrefix + orgId, org.workingHours);
    final wj = OrganizationWorkingHoursWeek.weekToPrefsJson(org.workingHoursWeek);
    if (wj != null) {
      await _prefs.setString(_kOrgWeekPrefix + orgId, wj);
    } else {
      await _prefs.remove(_kOrgWeekPrefix + orgId);
    }
    await _prefs.setString(_kOrgKindPrefix + orgId, org.businessKind);
    await _prefs.setString(_kOrgSchedulingModePrefix + orgId, org.schedulingMode);
  }

  /// Загрузить организацию: при наличии orgId — GET API, иначе или при ошибке — из prefs.
  Future<void> load(String? orgId) async {
    _orgId = orgId;
    if (orgId == null || orgId.isEmpty) {
      if (mounted) state = AsyncValue.data(_loadFromPrefs(null));
      return;
    }
    final result = await _api.get(orgId);
    if (!mounted) return;
    final data = result.dataOrNull;
    if (data != null) {
      state = AsyncValue.data(data);
      await _saveToPrefs(data);
    } else {
      state = AsyncValue.data(_loadFromPrefs(orgId));
    }
  }

  /// Загрузить фото точки (отображается в карточке у клиентов).
  Future<Result<String>> addPhoto(String? orgId, File imageFile) async {
    if (orgId == null || orgId.isEmpty) {
      return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Нет организации'));
    }
    final result = await _api.addPhoto(orgId, imageFile);
    final url = result.dataOrNull;
    if (url != null) {
      await load(orgId);
    }
    return result;
  }

  /// Загрузка из байтов (надёжнее с галереей на части Android-устройств).
  Future<Result<String>> addPhotoBytes(String? orgId, Uint8List bytes, String filename) async {
    if (orgId == null || orgId.isEmpty) {
      return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Нет организации'));
    }
    final result = await _api.addPhotoBytes(orgId, bytes, filename);
    final url = result.dataOrNull;
    if (url != null) {
      await load(orgId);
    }
    return result;
  }

  /// Удалить фото точки ([photoUrl] — строка из `photo_urls` в модели организации).
  Future<Result<bool>> deletePhoto(String? orgId, String photoUrl) async {
    if (orgId == null || orgId.isEmpty) {
      return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Нет организации'));
    }
    final trimmed = photoUrl.trim();
    if (trimmed.isEmpty) {
      return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Не указан адрес фото'));
    }
    final result = await _api.deletePhoto(orgId, trimmed);
    if (result.dataOrNull == true) {
      await load(orgId);
    }
    return result;
  }

  /// Обновить организацию: PATCH API, затем обновить state и prefs.
  Future<Result<OrganizationInfo>> update(OrganizationInfo org) async {
    final orgId = _orgId;
    if (orgId != null && orgId.isNotEmpty) {
      final result = await _api.update(orgId, org);
      final updated = result.dataOrNull;
      if (updated != null) {
        final prev = state.valueOrNull;
        // PATCH может не возвращать photo_urls и раньше не возвращал subscription_usage
        final merged = updated.copyWith(
          photoUrls: prev?.photoUrls ?? updated.photoUrls,
          subscriptionUsage: updated.subscriptionUsage ?? prev?.subscriptionUsage,
          workingHoursWeek: updated.workingHoursWeek ?? prev?.workingHoursWeek,
        );
        state = AsyncValue.data(merged);
        await _saveToPrefs(merged);
        return Result.success(merged);
      }
      return Result.failure(result.errorOrNull!);
    }
    await _saveToPrefs(org);
    state = AsyncValue.data(org);
    return Result.success(org);
  }
}

final organizationRepositoryProvider = StateNotifierProvider<OrganizationRepository, AsyncValue<OrganizationInfo>>((ref) {
  final api = ref.watch(organizationApiServiceProvider);
  final prefs = ref.watch(sharedPreferencesOrgProvider).valueOrNull;
  if (prefs == null) {
    return OrganizationRepository(api, _StubPrefs(), ref);
  }
  return OrganizationRepository(api, prefs, ref);
});

/// Для экранов: текущие данные организации (из репозитория).
final organizationProvider = Provider<AsyncValue<OrganizationInfo>>((ref) {
  return ref.watch(organizationRepositoryProvider);
});

Future<void> saveOrganization(SharedPreferences prefs, OrganizationInfo org, {String? orgId}) async {
  final prefix = orgId != null && orgId.isNotEmpty ? orgId : '';
  if (prefix.isEmpty) return;
  await prefs.setString(_kOrgNamePrefix + prefix, org.name);
  await prefs.setString(_kOrgAddressPrefix + prefix, org.address);
  await prefs.setString(_kOrgPhonePrefix + prefix, org.phone);
  await prefs.setString(_kOrgHoursPrefix + prefix, org.workingHours);
  final wj = OrganizationWorkingHoursWeek.weekToPrefsJson(org.workingHoursWeek);
  if (wj != null) {
    await prefs.setString(_kOrgWeekPrefix + prefix, wj);
  } else {
    await prefs.remove(_kOrgWeekPrefix + prefix);
  }
  await prefs.setString(_kOrgKindPrefix + prefix, org.businessKind);
  await prefs.setString(_kOrgSchedulingModePrefix + prefix, org.schedulingMode);
}

class _StubPrefs implements SharedPreferences {
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
  List<String>? getStringList(String key) => null;
  @override
  Future<bool> setString(String key, String value) async => false;
  @override
  Future<bool> setBool(String key, bool value) async => false;
  @override
  Future<bool> setInt(String key, int value) async => false;
  @override
  Future<bool> setDouble(String key, double value) async => false;
  @override
  Future<bool> setStringList(String key, List<String> value) async => false;
  @override
  Future<bool> remove(String key) async => false;
  @override
  Future<bool> clear() async => false;
  @override
  bool containsKey(String key) => false;
  @override
  Future<bool> commit() async => false;
  @override
  Future<bool> reload() async => false;
}
