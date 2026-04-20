import '../../shared/models/staff_model.dart';
import '../auth/auth_provider.dart';

MasterScheduleSlot? _scheduleSlotForDay(List<MasterScheduleSlot> schedule, int dayOfWeek) {
  for (final s in schedule) {
    if (s.dayOfWeek == dayOfWeek) return s;
  }
  return null;
}

/// Мастера, у которых выбранный день — рабочий (как в мобильном расписании).
List<StaffEntry> mastersOnShiftForDate(List<StaffEntry> staff, DateTime date) {
  final dayOfWeek = date.weekday % 7;
  return staff
      .where((e) {
        if (!e.isActive || e.role != StaffRole.master) return false;
        final slot = _scheduleSlotForDay(e.schedule, dayOfWeek);
        return slot != null && slot.isWorkingDay;
      })
      .toList();
}

/// Для самозанятого в расписании показываем только колонку, привязанную к текущему пользователю.
List<StaffEntry> filterMastersForScheduleRole(
  List<StaffEntry> masters,
  BusinessRole? role,
  String? currentUserId,
) {
  if (role != BusinessRole.solo) return masters;
  if (currentUserId == null || currentUserId.isEmpty) return masters;
  final mine = masters.where((e) => e.userId != null && e.userId == currentUserId).toList();
  if (mine.isNotEmpty) return mine;
  // Legacy: один мастер в организации без user_id в ответе API — колонка самозанятого всё равно нужна.
  if (masters.length == 1) return masters;
  return mine;
}
