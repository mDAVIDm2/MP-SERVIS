import 'dart:math' as math;

import 'package:flutter/services.dart';

/// Российский госномер (тип 1): 1 буква + 3 цифры + 2 буквы + 3 цифры региона.
/// Допустимы буквы кириллицы (АВЕКМНОРСТУХ) и латиницы, совпадающие по начертанию.
class RussianGibddPlate {
  RussianGibddPlate._();

  /// Буквы, разрешённые на знаках РФ (без Ё).
  static const String allowedCyrillicLetters = 'АВЕКМНОРСТУХ';
  static const String allowedLatinLetters = 'ABCEKMHOPCTYX';

  static String _normalizeLetter(String ch) {
    if (ch.isEmpty) return ch;
    final c = ch.toUpperCase();
    const map = {
      'A': 'А',
      'B': 'В',
      'C': 'С',
      'E': 'Е',
      'H': 'Н',
      'K': 'К',
      'M': 'М',
      'O': 'О',
      'P': 'Р',
      'T': 'Т',
      'X': 'Х',
      'Y': 'У',
    };
    if (map.containsKey(c)) return map[c]!;
    return c;
  }

  /// Компактная строка (9 символов макс.): символы принимаются **только в нужной позиции**
  /// (буква → 3 цифры → 2 буквы → 3 цифры). Лишние буквы в слотах цифр и наоборот отбрасываются.
  /// Латиница допустима только там, где она совпадает с буквами на знаках (см. [_normalizeLetter]).
  static String compact(String raw) {
    final buf = StringBuffer();
    var slot = 0;
    for (final r in raw.runes) {
      if (slot >= 9) break;
      final ch = String.fromCharCode(r);
      if (ch == ' ' || ch == '\u00A0') continue;

      final letterSlot = slot == 0 || slot == 4 || slot == 5;
      if (letterSlot) {
        if (!RegExp(r'[A-Za-zА-Яа-яЁё]', unicode: true).hasMatch(ch)) continue;
        final n = _normalizeLetter(ch);
        if (n.length == 1 && allowedCyrillicLetters.contains(n)) {
          buf.write(n);
          slot++;
        }
      } else {
        if (RegExp(r'[0-9]').hasMatch(ch)) {
          buf.write(ch);
          slot++;
        }
      }
    }
    return buf.toString();
  }

  /// Отображение с пробелами: «А 123 ВС 777».
  static String formatDisplay(String raw) {
    final c = compact(raw);
    if (c.isEmpty) return '';
    final parts = <String>[c.substring(0, 1)];
    if (c.length >= 2) {
      parts.add(c.substring(1, math.min(4, c.length)));
    }
    if (c.length >= 5) {
      parts.add(c.substring(4, math.min(6, c.length)));
    }
    if (c.length >= 7) {
      parts.add(c.substring(6, math.min(9, c.length)));
    }
    return parts.join(' ');
  }

  /// Валидность после [compact]: ровно 9 символов, шаблон буква-3цифры-2буквы-3цифры.
  static bool isValid(String raw) {
    final c = compact(raw);
    if (c.length != 9) return false;
    final re = RegExp(
      '^[$allowedCyrillicLetters]'
      r'\d{3}'
      '[$allowedCyrillicLetters]{2}'
      r'\d{3}$',
    );
    return re.hasMatch(c);
  }

  static String? validationMessageRu(String raw) {
    final c = compact(raw);
    if (c.isEmpty) return 'Введите госномер';
    if (c.length < 9) return 'Номер неполный: буква, 3 цифры, 2 буквы, 3 цифры региона';
    if (c.length > 9) return 'Слишком много символов';
    if (!isValid(raw)) {
      return 'Используйте буквы А, В, Е, К, М, Н, О, Р, С, Т, У, Х и цифры в формате: А 123 ВС 777';
    }
    return null;
  }
}

/// Ввод с автоформатированием пробелов под шаблон госномера.
class RussianPlateDisplayFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final c = RussianGibddPlate.compact(newValue.text);
    if (c.isEmpty) {
      return TextEditingValue.empty;
    }
    var clipped = c;
    if (clipped.length > 9) clipped = clipped.substring(0, 9);

    final display = RussianGibddPlate.formatDisplay(clipped);
    return TextEditingValue(
      text: display,
      selection: TextSelection.collapsed(offset: display.length),
      composing: TextRange.empty,
    );
  }
}
