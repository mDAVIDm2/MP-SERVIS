import 'staff_model.dart';

enum StaffInvitationStatus {
  pending,
  accepted,
  declined,
  cancelled,
  expired;

  static StaffInvitationStatus fromString(String? value) {
    return StaffInvitationStatus.values.firstWhere(
      (e) => e.name == (value ?? '').toLowerCase(),
      orElse: () => StaffInvitationStatus.pending,
    );
  }
}

class StaffInvitation {
  final String id;
  final String organizationId;
  final String? organizationName;
  final StaffRole role;
  final String? invitedName;
  final String? invitedEmail;
  final String? invitedPhone;
  final StaffInvitationStatus status;
  final String? message;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  const StaffInvitation({
    required this.id,
    required this.organizationId,
    this.organizationName,
    required this.role,
    this.invitedName,
    this.invitedEmail,
    this.invitedPhone,
    required this.status,
    this.message,
    this.createdAt,
    this.expiresAt,
  });

  factory StaffInvitation.fromJson(Map<String, dynamic> j) {
    return StaffInvitation(
      id: j['id'] as String? ?? '',
      organizationId: j['organization_id'] as String? ?? '',
      organizationName: j['organization_name'] as String?,
      role: StaffRole.fromString(j['role'] as String?),
      invitedName: j['invited_name'] as String?,
      invitedEmail: j['invited_email'] as String?,
      invitedPhone: j['invited_phone'] as String?,
      status: StaffInvitationStatus.fromString(j['status'] as String?),
      message: j['message'] as String?,
      createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at'] as String) : null,
      expiresAt: j['expires_at'] != null ? DateTime.tryParse(j['expires_at'] as String) : null,
    );
  }
}
