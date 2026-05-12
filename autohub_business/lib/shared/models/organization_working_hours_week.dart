import 'dart:convert';

/// Один день: пн…вс по индексу [OrganizationWorkingHoursWeek.dayLabels].
class OrganizationDayHours {
  const OrganizationDayHours({
    required this.open,
    required this.close,
    this.closed = false,
  });

  /// «HH:mm»
  final String open;
  final String close;
  final bool closed;

  Map<String, dynamic> toJson() => {
    'open': open,
    'close': close,
    if (closed) 'closed': true,
  };

  static OrganizationDayHours fromJson(Map<String, dynamic> m) {
    var closed = m['closed'] == true;
    var open = m['open'] as String? ?? '09:00';
    var close = m['close'] as String? ?? '19:00';
    if (!closed && open == '00:00' && close == '00:00') {
      closed = true;
    }
    return OrganizationDayHours(
      open: open,
      close: close,
      closed: closed,
    );
  }

  OrganizationDayHours copyWith({String? open, String? close, bool? closed}) {
    return OrganizationDayHours(
      open: open ?? this.open,
      close: close ?? this.close,
      closed: closed ?? this.closed,
    );
  }
}

/// Ровно 7 дней, индекс 0 = понедельник.
class OrganizationWorkingHoursWeek {
  const OrganizationWorkingHoursWeek(this.days) : assert(days.length == 7);

  final List<OrganizationDayHours> days;

  static const dayLabels = <String>[
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
    'Суббота',
    'Воскресенье',
  ];

  /// Пн–Пт 9:00–19:00, Сб 10:00–16:00, Вс: выходной
  static OrganizationWorkingHoursWeek defaultTemplate() {
    return OrganizationWorkingHoursWeek([
      for (var i = 0; i < 5; i++) const OrganizationDayHours(open: '09:00', close: '19:00'),
      const OrganizationDayHours(open: '10:00', close: '16:00'),
      const OrganizationDayHours(open: '00:00', close: '00:00', closed: true),
    ]);
  }

  static OrganizationWorkingHoursWeek? tryParseJson(dynamic raw) {
    if (raw is! List) return null;
    if (raw.length != 7) return null;
    try {
      final list = <OrganizationDayHours>[];
      for (final e in raw) {
        if (e is! Map) return null;
        list.add(OrganizationDayHours.fromJson(Map<String, dynamic>.from(e)));
      }
      return OrganizationWorkingHoursWeek(list);
    } catch (_) {
      return null;
    }
  }

  static String? weekToPrefsJson(OrganizationWorkingHoursWeek? w) {
    if (w == null) return null;
    return jsonEncode(w.days.map((d) => d.toJson()).toList());
  }

  static OrganizationWorkingHoursWeek? weekFromPrefsJson(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      final raw = jsonDecode(s);
      return tryParseJson(raw);
    } catch (_) {
      return null;
    }
  }
}
