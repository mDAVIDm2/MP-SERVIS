import '../../shared/models/order_model.dart';
import '../../shared/models/settings_models.dart';

/// Занятый интервал в минутах от полуночи [start, end).
class BusyMinutesRange {
  final int startMinutes;
  final int endMinutes;
  const BusyMinutesRange(this.startMinutes, this.endMinutes);
}

/// Пересечения с [busy] (другие заказы на этот день).
bool isCalendarMinutesIntervalFree({
  required int startMinutes,
  required int durationMinutes,
  required List<BusyMinutesRange> busy,
}) {
  if (durationMinutes <= 0) return true;
  final endM = startMinutes + durationMinutes;
  return !busy.any((b) => startMinutes < b.endMinutes && endM > b.startMinutes);
}

/// Занятость по заказам на календарный день (локальное время).
///
/// Важно: [day] и сетка слотов — в локальном календаре. Поля заказа с API часто в UTC
/// (`...Z`); без [orderStartWallClock] часы/дни смешиваются и занятость рисуется не в тех ячейках.
List<BusyMinutesRange> busyMinuteRangesForOrdersDay(
  List<Order> orders,
  DateTime day, {
  String? masterId,
}) {
  final dayStart = DateTime(day.year, day.month, day.day);
  final out = <BusyMinutesRange>[];
  for (final o in orders) {
    if (masterId != null && masterId.isNotEmpty) {
      final om = o.masterId;
      if (om != null && om.isNotEmpty && om != masterId) continue;
    }
    final raw = o.plannedStartTime ?? o.dateTime;
    if (raw == null) continue;
    final wall = orderStartWallClock(raw);
    if (wall == null) continue;
    final d = DateTime(wall.year, wall.month, wall.day);
    if (d != dayStart) continue;
    final startM = wall.hour * 60 + wall.minute;
    final dur = o.items.fold<int>(0, (s, i) => s + i.estimatedMinutes);
    final useDur = dur > 0 ? dur : 60;
    out.add(BusyMinutesRange(startM, startM + useDur));
  }
  return out;
}

/// Параметры сетки «время записи» (шаг и границы дня).
class SlotGridDimensions {
  final int slotDurationMinutes;
  final int workStartMinutes;
  final int workEndMinutes;

  const SlotGridDimensions({
    required this.slotDurationMinutes,
    required this.workStartMinutes,
    required this.workEndMinutes,
  });
}

String _minutesToHm(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// Метки слотов с шагом [slotDurationMinutes] от начала до конца рабочего дня.
List<String> timeSlotLabelsForGrid(SlotGridDimensions dims) {
  final step = dims.slotDurationMinutes.clamp(15, 240);
  final list = <String>[];
  for (var m = dims.workStartMinutes; m < dims.workEndMinutes; m += step) {
    list.add(_minutesToHm(m));
  }
  return list;
}

List<String> timeSlotLabelsFromSlotsSettings(SlotsSettings s) => timeSlotLabelsForGrid(SlotGridDimensions(
      slotDurationMinutes: s.slotDurationMinutes,
      workStartMinutes: s.startHour * 60 + s.startMinute,
      workEndMinutes: s.endHour * 60 + s.endMinute,
    ));

/// API приоритетнее локальных настроек — сетка совпадает с расчётом слотов на сервере.
SlotGridDimensions slotGridDimensionsFromApiOrLocal(AvailableSlotsResult? api, SlotsSettings local) {
  if (api != null && api.slotDurationMinutes > 0) {
    final we = api.workEndMinutes < api.workStartMinutes ? api.workStartMinutes + 60 : api.workEndMinutes;
    return SlotGridDimensions(
      slotDurationMinutes: api.slotDurationMinutes.clamp(15, 240),
      workStartMinutes: api.workStartMinutes,
      workEndMinutes: we,
    );
  }
  return SlotGridDimensions(
    slotDurationMinutes: local.slotDurationMinutes.clamp(15, 240),
    workStartMinutes: local.startHour * 60 + local.startMinute,
    workEndMinutes: local.endHour * 60 + local.endMinute,
  );
}

int timeLabelToMinutes(String slot) {
  final parts = slot.split(':');
  final h = int.tryParse(parts[0]) ?? 0;
  final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  return h * 60 + m;
}

/// Начало записи в локальных часах (сетка и ответ available-slots — локальное время).
DateTime? orderStartWallClock(DateTime? t) {
  if (t == null) return null;
  return t.isUtc ? t.toLocal() : t;
}

/// Ячейка — начало предложенного интервала в выбранный [day].
bool slotIsJobStartLabel(String slotLabel, DateTime? jobStart, DateTime day) {
  final jl = orderStartWallClock(jobStart);
  if (jl == null) return false;
  if (jl.year != day.year || jl.month != day.month || jl.day != day.day) return false;
  return timeLabelToMinutes(slotLabel) == jl.hour * 60 + jl.minute;
}

/// Ячейка попадает внутрь [jobStart, jobStart + jobDurationMinutes), но не является началом.
bool slotIsJobContinuationLabel(String slotLabel, DateTime? jobStart, DateTime day, int jobDurationMinutes) {
  final jl = orderStartWallClock(jobStart);
  if (jl == null || jobDurationMinutes <= 0) return false;
  if (jl.year != day.year || jl.month != day.month || jl.day != day.day) return false;
  final sm = timeLabelToMinutes(slotLabel);
  final jm = jl.hour * 60 + jl.minute;
  final endM = jm + jobDurationMinutes;
  return sm > jm && sm < endM;
}
