/// Только цифры (для СТС/ПТС и т.п.).
String _digitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');

/// Проверка поля «номер / данные» по типу документа. null — ок, иначе текст ошибки.
String? validateCarDocumentDetail(String type, String raw) {
  final t = raw.trim();
  if (t.isEmpty) return 'Введите номер или данные документа';

  switch (type) {
    case 'ОСАГО':
      return _validateOsago(t);
    case 'VIN':
      return _validateVinDoc(t);
    case 'Техосмотр':
      return _validateInspection(t);
    case 'СТС':
      return _validateSts(t);
    case 'ПТС':
      return _validatePts(t);
    case 'Другое':
      if (t.length > 200) return 'Не более 200 символов';
      return null;
    default:
      return null;
  }
}

String? _validateOsago(String t) {
  final compact = t.toUpperCase().replaceAll(RegExp(r'\s'), '');
  final re = RegExp(r'^[A-ZА-ЯЁ]{3}\d{10}$');
  if (!re.hasMatch(compact)) {
    return 'ОСАГО: 3 буквы серии (латиница или кириллица) и 10 цифр номера, например ААА1234567890';
  }
  return null;
}

/// VIN в документе: классический 17 символов без I, O, Q.
String? _validateVinDoc(String t) {
  final s = t.toUpperCase().replaceAll(RegExp(r'\s'), '');
  if (s.length != 17) {
    return 'VIN: ровно 17 символов (латиница и цифры)';
  }
  if (!RegExp(r'^[A-HJ-NPR-Z0-9]{17}$').hasMatch(s)) {
    return 'VIN: недопустимые символы (не используйте I, O, Q)';
  }
  return null;
}

String? _validateInspection(String t) {
  final c = t.replaceAll(RegExp(r'\s'), '');
  if (c.length < 8 || c.length > 24) {
    return 'Диагностическая карта: 8–24 символа без пробелов';
  }
  if (!RegExp(r'^[A-Za-zА-Яа-яЁё0-9-]+$').hasMatch(c)) {
    return 'Допустимы буквы, цифры и дефис';
  }
  return null;
}

/// СТС: серия 4 цифры + номер 6 цифр (10 цифр подряд, пробелы можно).
String? _validateSts(String t) {
  final d = _digitsOnly(t);
  if (d.length != 10) {
    return 'СТС: 10 цифр (4 цифры серии и 6 цифр номера)';
  }
  return null;
}

/// ПТС: чаще всего те же 10 цифр, что и у СТС.
String? _validatePts(String t) {
  final d = _digitsOnly(t);
  if (d.length != 10) {
    return 'ПТС: 10 цифр (серия и номер)';
  }
  return null;
}

/// Подсказка для поля ввода по типу.
String carDocumentDetailHint(String type) {
  switch (type) {
    case 'ОСАГО':
      return 'ААА 1234567890 (3 буквы и 10 цифр)';
    case 'VIN':
      return '17 символов, без I, O, Q';
    case 'Техосмотр':
      return 'Номер диагностической карты';
    case 'СТС':
      return '1234 567890 (10 цифр)';
    case 'ПТС':
      return '10 цифр серии и номера';
    case 'Другое':
      return 'Краткое описание';
    default:
      return '';
  }
}
