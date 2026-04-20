/// Парсинг строки срока документа вида «до 15 марта 2026» (как в профиле).
DateTime? parseCarDocumentExpiryDate(String? expiry) {
  if (expiry == null) return null;
  final match = RegExp(
    r'до\s+(\d{1,2})\s+(января|февраля|марта|апреля|мая|июня|июля|августа|сентября|октября|ноября|декабря)\s+(\d{4})',
  ).firstMatch(expiry.trim());
  if (match == null) return null;
  const months = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];
  final day = int.tryParse(match.group(1) ?? '') ?? 0;
  final month = months.indexWhere((m) => m == match.group(2)) + 1;
  final year = int.tryParse(match.group(3) ?? '') ?? 0;
  if (month < 1 || day < 1 || day > 31) return null;
  try {
    return DateTime(year, month, day);
  } catch (_) {
    return null;
  }
}

/// Дней от сегодня до даты (полуночь к полуночи); null если дату не разобрать.
int? daysUntilExpiryFromString(String? expiry) {
  final d = parseCarDocumentExpiryDate(expiry);
  if (d == null) return null;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final end = DateTime(d.year, d.month, d.day);
  return end.difference(today).inDays;
}
