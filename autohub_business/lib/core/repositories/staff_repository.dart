import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/models/staff_model.dart';
import '../../shared/models/staff_invitation_model.dart';
import '../api/api_exceptions.dart';
import '../api/services/api_services_providers.dart';
import '../api/services/staff_api_service.dart';
import '../auth/auth_provider.dart';
import 'organization_repository.dart';

const _kStaffListPrefix = 'staff_list_';

/// Репозиторий персонала: загрузка с API (GET), invite/update/deactivate/activate через API + кэш в prefs по orgId.
class StaffRepository extends StateNotifier<List<StaffEntry>> {
  StaffRepository(this._api, this._prefs, this._ref) : super([]) {
    final orgId = _ref.read(authProvider).user?.organizationId;
    _orgId = orgId;
    state = _loadFromPrefs(_prefs, orgId);
    load(orgId);
    _ref.listen<AuthState>(authProvider, (prev, next) {
      final nextId = next.user?.organizationId;
      if (nextId != _orgId) load(nextId);
    });
  }

  final StaffApiService _api;
  final SharedPreferences _prefs;
  final Ref _ref;
  String? _orgId;

  static List<StaffEntry> _loadFromPrefs(SharedPreferences prefs, String? orgId) {
    if (orgId == null || orgId.isEmpty) return [];
    final raw = prefs.getString(_kStaffListPrefix + orgId);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => StaffEntry.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  void _save() {
    final orgId = _orgId;
    if (orgId == null) return;
    _prefs.setString(_kStaffListPrefix + orgId, jsonEncode(state.map((e) => e.toJson()).toList()));
  }

  List<StaffEntry> get activeStaff => state.where((e) => e.isActive).toList();

  /// Загрузить персонал: при наличии orgId — GET API, иначе или при ошибке — из prefs.
  Future<void> load(String? orgId) async {
    _orgId = orgId;
    if (orgId == null || orgId.isEmpty) {
      if (mounted) state = _loadFromPrefs(_prefs, null);
      return;
    }
    final result = await _api.getStaff(orgId);
    if (!mounted) return;
    final data = result.dataOrNull;
    if (data != null) {
      state = data;
      _save();
    } else {
      state = _loadFromPrefs(_prefs, orgId);
    }
  }

  Future<Result<StaffInvitation>> invite({
    String? name,
    String? phone,
    String? email,
    required StaffRole role,
  }) async {
    final orgId = _orgId;
    if (orgId != null && orgId.isNotEmpty) {
      final result = await _api.invite(orgId, name: name, phone: phone, email: email, role: role);
      final inv = result.dataOrNull;
      if (inv != null) {
        return Result.success(inv);
      }
      return Result.failure(result.errorOrNull!);
    }
    final id = 'inv_${DateTime.now().millisecondsSinceEpoch}';
    final inv = StaffInvitation(
      id: id,
      organizationId: orgId ?? '',
      organizationName: null,
      role: role,
      invitedName: name?.trim().isEmpty == true ? null : name?.trim(),
      invitedPhone: phone?.trim().isEmpty == true ? null : phone?.trim(),
      invitedEmail: email?.trim().isEmpty == true ? null : email?.trim(),
      status: StaffInvitationStatus.pending,
      createdAt: DateTime.now(),
    );
    return Result.success(inv);
  }

  Future<Result<List<StaffInvitation>>> getIncomingInvitations() async {
    final result = await _api.getIncomingInvitations();
    final list = result.dataOrNull;
    if (list != null) return Result.success(list);
    return Result.failure(result.errorOrNull!);
  }

  Future<Result<List<StaffInvitation>>> getOrganizationInvitations({
    StaffInvitationStatus? status,
  }) async {
    final orgId = _orgId;
    if (orgId == null || orgId.isEmpty) {
      return Result.success(const []);
    }
    final result = await _api.getOrganizationInvitations(orgId, status: status);
    final list = result.dataOrNull;
    if (list != null) return Result.success(list);
    return Result.failure(result.errorOrNull!);
  }

  Future<Result<void>> acceptIncomingInvitation(String invitationId, {bool setActiveOrganization = true}) {
    return _api.acceptIncomingInvitation(invitationId, setActiveOrganization: setActiveOrganization);
  }

  Future<Result<void>> declineIncomingInvitation(String invitationId) {
    return _api.declineIncomingInvitation(invitationId);
  }

  Future<Result<void>> cancelOrganizationInvitation(String invitationId) async {
    final orgId = _orgId;
    if (orgId == null || orgId.isEmpty) {
      return Result.failure(const ApiException(code: ApiErrorCode.validation, message: 'Организация не выбрана'));
    }
    return _api.cancelOrganizationInvitation(orgId, invitationId);
  }

  Future<Result<StaffEntry>> update(StaffEntry entry) async {
    final orgId = _orgId;
    if (orgId != null && orgId.isNotEmpty) {
      final result = await _api.update(orgId, entry.id, entry);
      final updated = result.dataOrNull;
      if (updated != null) {
        state = state.map((e) => e.id == entry.id ? updated : e).toList();
        _save();
        return Result.success(updated);
      }
      return Result.failure(result.errorOrNull!);
    }
    state = state.map((e) => e.id == entry.id ? entry : e).toList();
    _save();
    return Result.success(entry);
  }

  Future<Result<void>> deactivate(String id) async {
    final orgId = _orgId;
    if (orgId != null && orgId.isNotEmpty) {
      final result = await _api.setActive(orgId, id, false);
      if (result.errorOrNull != null) {
        return Result.failure(result.errorOrNull!);
      }
      state = state.map((e) => e.id == id ? e.copyWith(isActive: false) : e).toList();
      _save();
      return Result.success(null);
    }
    state = state.map((e) => e.id == id ? e.copyWith(isActive: false) : e).toList();
    _save();
    return Result.success(null);
  }

  Future<Result<void>> activate(String id) async {
    final orgId = _orgId;
    if (orgId != null && orgId.isNotEmpty) {
      final result = await _api.setActive(orgId, id, true);
      if (result.errorOrNull != null) {
        return Result.failure(result.errorOrNull!);
      }
      state = state.map((e) => e.id == id ? e.copyWith(isActive: true) : e).toList();
      _save();
      return Result.success(null);
    }
    state = state.map((e) => e.id == id ? e.copyWith(isActive: true) : e).toList();
    _save();
    return Result.success(null);
  }

  StaffEntry? getById(String id) {
    try {
      return state.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Добавить текущего пользователя (владелец/админ) как мастера. После вызова нужно задать график в карточке сотрудника.
  Future<Result<StaffEntry>> addMeAsMaster() async {
    final orgId = _orgId;
    if (orgId == null || orgId.isEmpty) {
      return Result.failure(const ApiException(code: ApiErrorCode.unauthorized, message: 'Нет организации'));
    }
    final result = await _api.addMeAsMaster(orgId);
    final entry = result.dataOrNull;
    if (entry != null) {
      state = [...state, entry];
      _save();
      return Result.success(entry);
    }
    return Result.failure(result.errorOrNull!);
  }

}

final staffRepositoryProvider = StateNotifierProvider<StaffRepository, List<StaffEntry>>((ref) {
  final api = ref.watch(staffApiServiceProvider);
  final prefs = ref.watch(sharedPreferencesOrgProvider).valueOrNull;
  if (prefs == null) return StaffRepository(api, _StubPrefs(), ref);
  return StaffRepository(api, prefs, ref);
});

class _StubPrefs implements SharedPreferences {
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
  @override
  Set<String> getKeys() => {};
}
