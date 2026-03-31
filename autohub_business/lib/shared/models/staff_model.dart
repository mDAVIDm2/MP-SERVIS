/// Навыки мастера (умное расписание).
const List<String> kSkillIds = [
  'MAINTENANCE', 'ENGINE', 'ELECTRICAL', 'DIAGNOSTICS', 'SUSPENSION', 'TIRES', 'BODY',
];

String skillLabel(String id) {
  const labels = {
    'MAINTENANCE': 'ТО и обслуживание',
    'ENGINE': 'Двигатель',
    'ELECTRICAL': 'Электрика',
    'DIAGNOSTICS': 'Диагностика',
    'SUSPENSION': 'Подвеска',
    'TIRES': 'Шины',
    'BODY': 'Кузов',
  };
  return labels[id] ?? id;
}

/// Один день графика работы (0 = вс, 1 = пн, ... 6 = сб).
class MasterScheduleSlot {
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final bool isWorkingDay;

  const MasterScheduleSlot({
    required this.dayOfWeek,
    this.startTime = '09:00',
    this.endTime = '18:00',
    this.isWorkingDay = true,
  });

  Map<String, dynamic> toJson() => {
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'end_time': endTime,
        'is_working_day': isWorkingDay,
      };

  static MasterScheduleSlot fromJson(Map<String, dynamic> j) {
    return MasterScheduleSlot(
      dayOfWeek: (j['day_of_week'] as num?)?.toInt() ?? 0,
      startTime: j['start_time'] as String? ?? '09:00',
      endTime: j['end_time'] as String? ?? '18:00',
      isWorkingDay: j['is_working_day'] as bool? ?? true,
    );
  }
}

/// Роль сотрудника в организации.
enum StaffRole {
  admin,
  master;

  String get label {
    switch (this) {
      case StaffRole.admin:
        return 'Администратор';
      case StaffRole.master:
        return 'Мастер';
    }
  }

  static StaffRole fromString(String? value) {
    if (value == null) return StaffRole.master;
    return StaffRole.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => StaffRole.master,
    );
  }
}

/// Сотрудник организации (для раздела Персонал).
class StaffEntry {
  final String id;
  /// ID пользователя приложения, если запись привязана к владельцу/админу (добавлен как мастер).
  final String? userId;
  final String name;
  final String? phone;
  final String? email;
  final StaffRole role;
  final bool isActive;
  final DateTime? invitedAt;
  /// Навыки мастера (MAINTENANCE, ENGINE, ELECTRICAL, ...).
  final List<String> skills;
  /// График работы по дням недели.
  final List<MasterScheduleSlot> schedule;

  const StaffEntry({
    required this.id,
    this.userId,
    required this.name,
    this.phone,
    this.email,
    required this.role,
    this.isActive = true,
    this.invitedAt,
    this.skills = const [],
    this.schedule = const [],
  });

  /// Запись соответствует текущему пользователю (владелец/админ, добавленный как мастер).
  bool get isCurrentUser => userId != null && userId!.isNotEmpty;

  StaffEntry copyWith({
    String? id,
    String? userId,
    String? name,
    String? phone,
    String? email,
    StaffRole? role,
    bool? isActive,
    DateTime? invitedAt,
    List<String>? skills,
    List<MasterScheduleSlot>? schedule,
  }) {
    return StaffEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      invitedAt: invitedAt ?? this.invitedAt,
      skills: skills ?? this.skills,
      schedule: schedule ?? this.schedule,
    );
  }

  String get roleLabel => role.label;

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'phone': phone,
        'email': email,
        'role': role.name,
        'isActive': isActive,
        'invitedAt': invitedAt?.toIso8601String(),
        'skills': skills,
        'schedule': schedule.map((s) => s.toJson()).toList(),
      };

  factory StaffEntry.fromJson(Map<String, dynamic> j) {
    final skillsRaw = j['skills'];
    final skills = skillsRaw is List ? skillsRaw.map((e) => e.toString()).toList() : <String>[];
    final scheduleRaw = j['schedule'] as List<dynamic>?;
    final schedule = scheduleRaw?.map((e) => MasterScheduleSlot.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    final userId = j['user_id'] as String? ?? j['userId'] as String?;
    return StaffEntry(
      id: j['id'] as String,
      userId: userId != null && userId.isNotEmpty ? userId : null,
      name: j['name'] as String,
      phone: j['phone'] as String?,
      email: j['email'] as String?,
      role: StaffRole.fromString(j['role'] as String?),
      isActive: j['isActive'] as bool? ?? (j['is_active'] as bool?) ?? true,
      invitedAt: j['invitedAt'] != null ? DateTime.tryParse(j['invitedAt'] as String) : (j['invited_at'] != null ? DateTime.tryParse(j['invited_at'] as String) : null),
      skills: skills,
      schedule: schedule,
    );
  }
}
