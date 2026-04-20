import 'package:intl/intl.dart';

String formatMoney(int kopecks) {
  final rub = kopecks / 100;
  return NumberFormat.currency(locale: 'ru_RU', symbol: '₽', decimalDigits: 0).format(rub);
}

/// Для отображения: всегда показываем в локальном времени устройства (как в клиентском приложении).
DateTime _local(DateTime d) => d.toLocal();

String formatDate(DateTime d) => DateFormat('dd.MM.yyyy').format(_local(d));
/// Короткая дата для списков: «6 мар.»
String formatDateShort(DateTime d) => DateFormat('d MMM', 'ru').format(_local(d));

/// Для карточки заказа: «Сегодня», «Завтра» или «6 мар.»
String formatOrderDatePart(DateTime d) {
  final local = _local(d);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final day = DateTime(local.year, local.month, local.day);
  if (day == today) return 'Сегодня';
  if (day == tomorrow) return 'Завтра';
  return formatDateShort(d);
}
String formatTime(DateTime d) => DateFormat('HH:mm').format(_local(d));
String formatDateTime(DateTime d) => DateFormat('dd.MM.yyyy HH:mm').format(_local(d));

String formatDateOrNull(DateTime? d) => d == null ? '—' : formatDate(d);
String formatTimeOrNull(DateTime? d) => d == null ? '—' : formatTime(d);
String formatDateTimeOrNull(DateTime? d) => d == null ? '—' : formatDateTime(d);

/// Человекочитаемая длительность: «2 ч 30 мин», «45 мин».
String formatDurationMinutes(int minutes) {
  if (minutes < 60) return '$minutes мин';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return '$h ч';
  return '$h ч $m мин';
}

/// Строка под итогом: эквивалентная ставка «руб/ч» по сумме и длительности записи.
String? formatEquivalentHourlyRateLine(int totalKopecks, int durationMinutes) {
  if (durationMinutes <= 0) return null;
  final koph = (totalKopecks * 60 + durationMinutes ~/ 2) ~/ durationMinutes;
  if (koph <= 0) return null;
  return '≈ ${formatMoney(koph)}/ч';
}
