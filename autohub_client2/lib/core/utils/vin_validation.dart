import 'package:flutter/services.dart';

/// Ввод VIN: сразу переводит латиницу в верхний регистр (цифры не трогает).
class VinUpperCaseTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final t = newValue.text.toUpperCase();
    if (t == newValue.text) return newValue;
    return TextEditingValue(
      text: t,
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}

/// Нормализация и проверка VIN: только A–Z и 0–9, до 32 символов (как на бэкенде).
String? normalizeVinOrNull(String? raw) {
  if (raw == null) return null;
  final s = raw.trim().toUpperCase().replaceAll(RegExp(r'\s'), '');
  if (s.isEmpty) return null;
  return s;
}

bool isValidVinFormat(String vin) {
  if (vin.length > 32) return false;
  return RegExp(r'^[A-Z0-9]+$').hasMatch(vin);
}

String? vinValidationMessageRu(String? raw) {
  final n = normalizeVinOrNull(raw);
  if (n == null) return null;
  if (!isValidVinFormat(n)) {
    return 'VIN: только заглавные латинские буквы и цифры, без пробелов (до 32 символов).';
  }
  return null;
}
