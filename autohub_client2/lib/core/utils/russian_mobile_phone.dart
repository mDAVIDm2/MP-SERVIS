import 'dart:math' as math;

import 'package:flutter/services.dart';

/// Российский мобильный номер: в поле ввода всегда префикс **+7** и до 10 цифр после него.
class RussianMobilePhone {
  RussianMobilePhone._();

  static const String prefix = '+7 ';

  /// Только цифры национальной части (10 шт), без ведущей 7.
  static String nationalDigitsFromAnyInput(String raw) {
    var d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.length >= 11 && d.startsWith('8')) {
      d = '7${d.substring(1)}';
    }
    if (d.length >= 11 && d.startsWith('7')) {
      d = d.substring(1);
    }
    if (d.length > 10) {
      d = d.substring(d.length - 10);
    }
    return d.length > 10 ? d.substring(0, 10) : d;
  }

  /// Отображаемая строка с +7 и группами.
  static String displayFromNationalDigits(String tenDigits) {
    final d = tenDigits.length > 10 ? tenDigits.substring(0, 10) : tenDigits;
    if (d.isEmpty) return prefix;
    final buf = StringBuffer(prefix.trimRight());
    buf.write(' ');
    if (d.length <= 3) {
      buf.write(d);
    } else if (d.length <= 6) {
      buf.write('${d.substring(0, 3)} ${d.substring(3)}');
    } else if (d.length <= 8) {
      buf.write('${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6)}');
    } else {
      buf.write('${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6, 8)} ${d.substring(8)}');
    }
    return buf.toString();
  }

  /// Из любого ввода — строка для поля (с +7).
  static String displayFromAny(String? raw) {
    if (raw == null || raw.trim().isEmpty) return prefix;
    return displayFromNationalDigits(nationalDigitsFromAnyInput(raw));
  }

  /// E.164 для API: +7XXXXXXXXXX
  static String? e164OrNull(String raw) {
    final n = nationalDigitsFromAnyInput(raw);
    if (n.length != 10) return null;
    return '+7$n';
  }

  static bool isComplete(String raw) => nationalDigitsFromAnyInput(raw).length == 10;

  /// Сколько цифр национальной части (до 10) попадает в подстроку [0, caret).
  static int nationalDigitCountBeforeCaret(String text, int caret) {
    if (caret <= 0) return 0;
    final sub = text.substring(0, math.min(caret, text.length));
    return nationalDigitsFromAnyInput(sub).length;
  }

  /// Смещение курсора после [digitCount] цифр национальной части (0 — сразу после префикса `+7 `).
  static int caretOffsetAfterNationalDigits(String display, int digitCount) {
    final maxDigits = 10;
    final n = digitCount.clamp(0, maxDigits);
    if (n <= 0) {
      return math.min(RussianMobilePhone.prefix.length, display.length);
    }
    var seen = 0;
    for (var i = 0; i < display.length; i++) {
      final c = display.codeUnitAt(i);
      final isDigit = c >= 0x30 && c <= 0x39;
      if (isDigit) {
        seen++;
        if (seen == n) return i + 1;
      }
    }
    return display.length;
  }
}

/// Форматтер: фиксирует +7, ввод только 10 цифр после страны; курсор не прыгает в конец при правках.
class RussianMobilePhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text;
    if (raw.isEmpty) {
      return TextEditingValue(
        text: RussianMobilePhone.prefix,
        selection: TextSelection.collapsed(offset: RussianMobilePhone.prefix.length),
        composing: TextRange.empty,
      );
    }
    var digits = RussianMobilePhone.nationalDigitsFromAnyInput(raw);
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }
    final display = RussianMobilePhone.displayFromNationalDigits(digits);

    final caretInRaw = newValue.selection.isValid ? newValue.selection.baseOffset : raw.length;
    var digitCount = RussianMobilePhone.nationalDigitCountBeforeCaret(raw, caretInRaw);
    digitCount = digitCount.clamp(0, 10);
    var offset = RussianMobilePhone.caretOffsetAfterNationalDigits(display, digitCount);
    offset = offset.clamp(0, display.length);

    return TextEditingValue(
      text: display,
      selection: TextSelection.collapsed(offset: offset),
      composing: TextRange.empty,
    );
  }
}
