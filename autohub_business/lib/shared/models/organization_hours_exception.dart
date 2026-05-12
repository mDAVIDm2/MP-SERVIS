/// Разовое исключение из недельного графика (дата в локальной зоне организации).
class OrganizationHoursException {
  const OrganizationHoursException({
    required this.date,
    this.closed = false,
    this.open,
    this.close,
  });

  final String date;
  final bool closed;
  final String? open;
  final String? close;

  Map<String, dynamic> toJson() {
    if (closed) return {'date': date, 'closed': true};
    return {'date': date, 'open': open ?? '09:00', 'close': close ?? '19:00'};
  }

  factory OrganizationHoursException.fromJson(Map<String, dynamic> j) {
    final date = j['date']?.toString() ?? '';
    if (j['closed'] == true) {
      return OrganizationHoursException(date: date, closed: true);
    }
    return OrganizationHoursException(
      date: date,
      open: j['open']?.toString(),
      close: j['close']?.toString(),
    );
  }

  static List<OrganizationHoursException>? tryParseList(dynamic raw) {
    if (raw is! List) return null;
    final out = <OrganizationHoursException>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final date = m['date']?.toString() ?? '';
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) continue;
      out.add(OrganizationHoursException.fromJson(m));
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }
}
