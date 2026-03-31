/// Логика доступности слотов записи у организации.
///
/// Шаг сетки задаётся [slotDurationMinutes] (как в настройках организации / ответе API).
/// Если у пользователя услуги на 3 часа, он может выбрать только такое время начала,
/// чтобы интервал [начало, начало + длительность] целиком был свободен.

/// Значение по умолчанию для обратной совместимости (если метаданные сетки не переданы).
const int defaultSlotMinutes = 30;

/// Минуты от полуночи для "HH:mm"
int timeToMinutes(String time) {
  final parts = time.split(':');
  final h = int.parse(parts[0]);
  final m = parts.length > 1 ? int.parse(parts[1]) : 0;
  return h * 60 + m;
}

String minutesToTime(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// Занятый интервал (в минутах от полуночи): [start, end)
class BusyRange {
  final int startMinutes;
  final int endMinutes;
  const BusyRange(this.startMinutes, this.endMinutes);
}

/// Метки слотов рабочего дня с шагом [slotDurationMinutes].
List<String> buildDaySlotLabels({
  int slotDurationMinutes = defaultSlotMinutes,
  int workStartMinutes = 9 * 60,
  int workEndMinutes = 18 * 60,
}) {
  final step = slotDurationMinutes.clamp(5, 240);
  final list = <String>[];
  for (var m = workStartMinutes; m < workEndMinutes; m += step) {
    list.add(minutesToTime(m));
  }
  return list;
}

/// @nodoc — используйте [buildDaySlotLabels].
List<String> allSlotsInDay({
  int workStartMinutes = 9 * 60,
  int workEndMinutes = 18 * 60,
}) =>
    buildDaySlotLabels(
      slotDurationMinutes: defaultSlotMinutes,
      workStartMinutes: workStartMinutes,
      workEndMinutes: workEndMinutes,
    );

/// Доступные **начала** визита для одного непрерывного блока длительностью [totalDurationMinutes].
/// Возвращает только те "HH:mm", с которых можно начать так, чтобы весь блок не пересекался с занятыми.
List<String> availableStartsForContiguousBlock({
  required int totalDurationMinutes,
  required List<BusyRange> busyRanges,
  int workStartMinutes = 9 * 60,
  int workEndMinutes = 18 * 60,
  int slotStepMinutes = defaultSlotMinutes,
}) {
  final result = <String>[];
  final step = slotStepMinutes.clamp(5, 240);
  final endLimit = workEndMinutes - totalDurationMinutes;
  for (var startM = workStartMinutes; startM <= endLimit; startM += step) {
    final endM = startM + totalDurationMinutes;
    final overlaps = busyRanges.any((b) {
      final bStart = b.startMinutes;
      final bEnd = b.endMinutes;
      return startM < bEnd && endM > bStart;
    });
    if (!overlaps) result.add(minutesToTime(startM));
  }
  return result;
}

/// Проверяет, свободен ли интервал [startMinutes, startMinutes + durationMinutes)
bool isIntervalFree({
  required int startMinutes,
  required int durationMinutes,
  required List<BusyRange> busyRanges,
}) {
  final endM = startMinutes + durationMinutes;
  return !busyRanges.any((b) =>
    startMinutes < b.endMinutes && endM > b.startMinutes);
}

/// Слот длительностью [slotDurationMinutes] считается занятым, если пересекается с [busyRanges].
bool isSlotOccupied(String slotTime, List<BusyRange> busyRanges, {int slotDurationMinutes = defaultSlotMinutes}) {
  final startM = timeToMinutes(slotTime);
  final endM = startM + slotDurationMinutes.clamp(5, 240);
  return busyRanges.any((b) => startM < b.endMinutes && endM > b.startMinutes);
}

/// Время записи в локальных часах (метки сетки и API — локальное время).
DateTime? orderStartWallClock(DateTime? t) {
  if (t == null) return null;
  return t.isUtc ? t.toLocal() : t;
}

/// Ячейка [slotLabel] — начало выбранной записи в этот [day].
bool slotIsJobStart(String slotLabel, DateTime? jobStart, DateTime day) {
  final jl = orderStartWallClock(jobStart);
  if (jl == null) return false;
  if (jl.year != day.year || jl.month != day.month || jl.day != day.day) return false;
  return timeToMinutes(slotLabel) == jl.hour * 60 + jl.minute;
}

/// Ячейка — не начало, но попадает внутрь интервала записи [jobStart, jobStart + jobDurationMinutes).
bool slotIsJobContinuation(String slotLabel, DateTime? jobStart, DateTime day, int jobDurationMinutes) {
  final jl = orderStartWallClock(jobStart);
  if (jl == null || jobDurationMinutes <= 0) return false;
  if (jl.year != day.year || jl.month != day.month || jl.day != day.day) return false;
  final sm = timeToMinutes(slotLabel);
  final jm = jl.hour * 60 + jl.minute;
  final endM = jm + jobDurationMinutes;
  return sm > jm && sm < endM;
}
