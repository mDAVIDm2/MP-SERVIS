import 'package:dio/dio.dart';
import '../api_client.dart';
import '../api_endpoints.dart';
import '../api_exceptions.dart';
import '../../../shared/models/staff_model.dart';
import '../../../shared/models/staff_invitation_model.dart';

/// API персонала организации.
class StaffApiService {
  StaffApiService(this._client);

  final ApiClient _client;

  static StaffEntry _entryFromJson(Map<String, dynamic> j) {
    final skillsRaw = j['skills'];
    final skills = skillsRaw is List ? skillsRaw.map((e) => e.toString()).toList() : <String>[];
    final scheduleRaw = j['schedule'] as List<dynamic>?;
    final schedule = scheduleRaw?.map((e) => MasterScheduleSlot.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    final userId = j['user_id'] as String? ?? j['userId'] as String?;
    return StaffEntry(
      id: j['id'] as String? ?? '',
      userId: userId != null && userId.isNotEmpty ? userId : null,
      name: j['name'] as String? ?? '',
      phone: j['phone'] as String?,
      email: j['email'] as String?,
      role: StaffRole.fromString(j['role'] as String?),
      isActive: j['is_active'] as bool? ?? j['isActive'] as bool? ?? true,
      invitedAt: j['invited_at'] != null ? DateTime.tryParse(j['invited_at'] as String) : (j['invitedAt'] != null ? DateTime.tryParse(j['invitedAt'] as String) : null),
      skills: skills,
      schedule: schedule,
      canSeeChats: j['can_see_chats'] as bool? ?? j['canSeeChats'] as bool? ?? false,
      canWriteChats: j['can_write_chats'] as bool? ?? j['canWriteChats'] as bool? ?? false,
      canManageOrgSettings:
          j['can_manage_org_settings'] as bool? ?? j['canManageOrgSettings'] as bool? ?? false,
    );
  }

  /// Добавить текущего пользователя (владелец/админ) как мастера. После вызова нужно задать график в карточке сотрудника.
  Future<Result<StaffEntry>> addMeAsMaster(String orgId) async {
    try {
      final res = await _client.post(ApiEndpoints.organizationStaffAddMeAsMaster(orgId));
      final data = res.data as Map<String, dynamic>?;
      if (data == null) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ'));
      }
      return Result.success(_entryFromJson(data));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<List<StaffEntry>>> getStaff(String orgId) async {
    try {
      final res = await _client.get(ApiEndpoints.organizationStaff(orgId));
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат'));
      }
      final list = data['items'] as List<dynamic>? ?? data['data'] as List<dynamic>? ?? data['staff'] as List<dynamic>? ?? [];
      final staff = list.map((e) => _entryFromJson(e as Map<String, dynamic>)).toList();
      return Result.success(staff);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<StaffInvitation>> invite(
    String orgId, {
    String? name,
    String? phone,
    String? email,
    required StaffRole role,
    String? message,
    int? expiresInDays,
  }) async {
    try {
      final body = {
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
        if (email != null && email.isNotEmpty) 'email': email.trim(),
        'role': role.name,
        if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
        if (expiresInDays != null && expiresInDays > 0) 'expires_in_days': expiresInDays,
      };
      final res = await _client.post(ApiEndpoints.organizationStaff(orgId), data: body);
      final data = res.data as Map<String, dynamic>?;
      if (data == null) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ'));
      }
      return Result.success(StaffInvitation.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<List<StaffInvitation>>> getOrganizationInvitations(
    String orgId, {
    StaffInvitationStatus? status,
  }) async {
    try {
      final res = await _client.get(
        ApiEndpoints.organizationInvitations(orgId),
        queryParameters: {
          if (status != null) 'status': status.name,
        },
      );
      final data = res.data as Map<String, dynamic>?;
      if (data == null) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ'));
      }
      final list = data['items'] as List<dynamic>? ?? [];
      return Result.success(list.map((e) => StaffInvitation.fromJson(e as Map<String, dynamic>)).toList());
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<List<StaffInvitation>>> getIncomingInvitations() async {
    try {
      final res = await _client.get(ApiEndpoints.profileInvitations);
      final data = res.data as Map<String, dynamic>?;
      if (data == null) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ'));
      }
      final list = data['items'] as List<dynamic>? ?? [];
      return Result.success(list.map((e) => StaffInvitation.fromJson(e as Map<String, dynamic>)).toList());
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<void>> acceptIncomingInvitation(String invitationId, {bool setActiveOrganization = true}) async {
    try {
      await _client.post(
        ApiEndpoints.profileInvitationAccept(invitationId),
        data: {'set_active_organization': setActiveOrganization},
      );
      return Result.success(null);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<void>> declineIncomingInvitation(String invitationId) async {
    try {
      await _client.post(ApiEndpoints.profileInvitationDecline(invitationId));
      return Result.success(null);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<void>> cancelOrganizationInvitation(String orgId, String invitationId) async {
    try {
      await _client.post(ApiEndpoints.organizationInvitationCancel(orgId, invitationId));
      return Result.success(null);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<StaffEntry>> update(String orgId, String staffId, StaffEntry entry) async {
    try {
      final body = {
        'name': entry.name,
        if (entry.phone != null) 'phone': entry.phone,
        if (entry.email != null) 'email': entry.email,
        'role': entry.role.name,
        'is_active': entry.isActive,
        'skills': entry.skills,
        'schedule': entry.schedule.map((s) => s.toJson()).toList(),
        'can_see_chats': entry.canSeeChats,
        'can_write_chats': entry.canWriteChats,
        'can_manage_org_settings': entry.canManageOrgSettings,
      };
      final res = await _client.patch(ApiEndpoints.organizationStaffMember(orgId, staffId), data: body);
      final data = res.data as Map<String, dynamic>?;
      if (data == null) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ'));
      }
      return Result.success(_entryFromJson(data));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<void>> setActive(String orgId, String staffId, bool isActive) async {
    try {
      await _client.patch(ApiEndpoints.organizationStaffMember(orgId, staffId), data: {'is_active': isActive});
      return Result.success(null);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }
}
