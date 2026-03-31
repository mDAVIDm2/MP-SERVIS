import '../../shared/models/order_model.dart';
import '../../shared/models/settings_models.dart';

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
