import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  /// Для отображения: всегда показываем в локальном времени устройства (как в Business).
  static DateTime _local(DateTime d) => d.toLocal();

  /// 12500 (копейки) → "125 ₽"
  static String money(int kopecks) {
    final rubles = kopecks ~/ 100;
    final formatter = NumberFormat('#,###', 'ru_RU');
    return '${formatter.format(rubles)} ₽';
  }

  /// 62850 → "62 850 км"
  static String mileage(int km) {
    final formatter = NumberFormat('#,###', 'ru_RU');
    return '${formatter.format(km)} км';
  }

  /// +79991234567 → "+7 (999) 123-45-67"
  static String phone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length == 11) {
      return '+${digits[0]} (${digits.substring(1, 4)}) ${digits.substring(4, 7)}-${digits.substring(7, 9)}-${digits.substring(9, 11)}';
    }
    return raw;
  }

  /// DateTime → "23 декабря 2025"
  static String dateFullRu(DateTime d) {
    return DateFormat('d MMMM yyyy', 'ru_RU').format(_local(d));
  }

  /// DateTime → "23 дек"
  static String dateShortRu(DateTime d) {
    return DateFormat('d MMM', 'ru_RU').format(_local(d));
  }

  /// DateTime → "23 дек 2025"
  static String dateShortYearRu(DateTime d) {
    return DateFormat('d MMM yyyy', 'ru_RU').format(_local(d));
  }

  /// DateTime → "14:30"
  static String time(DateTime d) {
    return DateFormat('HH:mm').format(_local(d));
  }

  /// DateTime → "23 дек, 09:00"
  static String dateTimeShort(DateTime d) {
    final l = _local(d);
    return '${DateFormat('d MMM', 'ru_RU').format(l)}, ${DateFormat('HH:mm').format(l)}';
  }

  /// Диапазон времени: "12:00 - 18:00". Если end null — только start.
  static String timeRange(DateTime start, DateTime? end) {
    final s = _local(start);
    if (end == null) return DateFormat('HH:mm').format(s);
    final e = _local(end);
    return '${DateFormat('HH:mm').format(s)} – ${DateFormat('HH:mm').format(e)}';
  }

  /// Расстояние: 0.3 → "300 м", 2.5 → "2.5 км"
  static String distance(double km) {
    if (km < 1) return '${(km * 1000).round()} м';
    if (km < 10) return '${km.toStringAsFixed(1)} км';
    if (km < 100) return '${km.round()} км';
    return '${km.round()}+ км';
  }

  /// Рейтинг: 4.8 → "4.8"
  static String rating(double r) => r.toStringAsFixed(1);

  /// Отзывы: 1 → "1 отзыв", 4 → "4 отзыва", 28 → "28 отзывов"
  static String reviewCount(int count) {
    final lastTwo = count % 100;
    final lastOne = count % 10;
    String word;
    if (lastTwo >= 11 && lastTwo <= 19) {
      word = 'отзывов';
    } else if (lastOne == 1) {
      word = 'отзыв';
    } else if (lastOne >= 2 && lastOne <= 4) {
      word = 'отзыва';
    } else {
      word = 'отзывов';
    }
    return '$count $word';
  }

  /// Время назад
  static String timeAgo(DateTime dateTime) {
    final l = _local(dateTime);
    final now = DateTime.now();
    final diff = now.difference(l);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
    if (diff.inHours < 24) return '${diff.inHours} ч назад';
    if (diff.inDays == 1) return 'вчера, ${time(dateTime)}';
    return dateTimeShort(dateTime);
  }

  /// День недели: Пн, Вт, ...
  static String weekdayShort(DateTime d) {
    return DateFormat('E', 'ru_RU').format(_local(d));
  }

  /// Длительность: 45 → "45 мин", 75 → "1:15 ч", 120 → "2:00 ч"; от суток — "2 дн", "1 дн 1:30 ч".
  static String durationMinutes(int minutes) {
    if (minutes <= 0) return '0 мин';
    if (minutes < 60) return '$minutes мин';
    if (minutes >= 1440) {
      final d = minutes ~/ 1440;
      final r = minutes % 1440;
      if (r == 0) return '$d дн';
      if (r < 60) return '$d дн $r мин';
      final h = r ~/ 60;
      final m = r % 60;
      return '$d дн $h:${m.toString().padLeft(2, '0')} ч';
    }
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '$h:${m.toString().padLeft(2, '0')} ч';
  }

  /// Дата + слот "HH:mm" → локальное [DateTime] начала записи.
  static DateTime? dateAtTimeSlot(DateTime date, String slotHHmm) {
    final parts = slotHHmm.trim().split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0].trim());
    final m = int.tryParse(parts[1].trim());
    if (h == null || m == null) return null;
    return DateTime(date.year, date.month, date.day, h, m);
  }

  /// Один и тот же календарный день в локальном времени устройства.
  static bool isSameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Для выбранного календарного дня: начало слота уже прошло или совпадает с текущим моментом — выбрать нельзя.
  /// Для не-сегодняшних дат всегда `false`.
  static bool isBookingSlotStartInPastOrNow(DateTime calendarDate, String slotHHmm) {
    final start = dateAtTimeSlot(calendarDate, slotHHmm);
    if (start == null) return true;
    final now = DateTime.now();
    if (!isSameCalendarDay(calendarDate, now)) return false;
    return !start.isAfter(now);
  }

  /// Диапазон для записи: "25 мар 10:00 — 11:15" или с датой окончания, если на следующий день.
  static String bookingRangeLabel(DateTime start, DateTime end) {
    final ls = _local(start);
    final le = _local(end);
    final startStr = '${dateShortRu(ls)} ${time(ls)}';
    final sameDay = ls.year == le.year && ls.month == le.month && ls.day == le.day;
    final endStr = sameDay ? time(le) : '${dateShortRu(le)} ${time(le)}';
    return '$startStr — $endStr';
  }

  /// Для чатов — время в карточке
  static String chatTime(DateTime dateTime) {
    final l = _local(dateTime);
    final now = DateTime.now();
    final diff = now.difference(l);
    if (diff.inMinutes < 60) return time(dateTime);
    if (diff.inDays == 0) return time(dateTime);
    if (diff.inDays == 1) return 'вчера';
    return dateShortRu(dateTime);
  }
}
