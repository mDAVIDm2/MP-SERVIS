import 'package:flutter/material.dart';
import '../../core/theme/client_palette.dart';

/// Допустимые буквы госномера РФ (кириллица, как в ГОСТ).
const String kRussianPlateLetters = 'АВЕКМНОРСТУХ';

/// Индексы позиций: 0 и 4–5 — буквы, остальные — цифры (формат А123АА777).
bool _slotIsLetter(int index) => index == 0 || index == 4 || index == 5;

/// Нормализация: латиница похожих букв → кириллица, верхний регистр, только цифры и допустимые буквы.
String normalizePlateInput(String raw) {
  const map = {
    'A': 'А', 'a': 'А',
    'B': 'В', 'b': 'В',
    'E': 'Е', 'e': 'Е',
    'K': 'К', 'k': 'К',
    'M': 'М', 'm': 'М',
    'H': 'Н', 'h': 'Н',
    'O': 'О', 'o': 'О',
    'P': 'Р', 'p': 'Р',
    'C': 'С', 'c': 'С',
    'T': 'Т', 't': 'Т',
    'Y': 'У', 'y': 'У',
    'X': 'Х', 'x': 'Х',
    'V': 'В', 'v': 'В',
  };
  final buf = StringBuffer();
  for (final r in raw.runes) {
    final ch = String.fromCharCode(r);
    if (ch == ' ' || ch == '\u00A0') continue;
    final mapped = map[ch] ?? ch;
    if (RegExp(r'^\d$').hasMatch(mapped)) {
      buf.write(mapped);
      continue;
    }
    if (kRussianPlateLetters.contains(mapped)) {
      buf.write(mapped);
    }
  }
  return buf.toString();
}

/// Проверка полного номера: 9 символов, буквы только из [kRussianPlateLetters].
bool isValidRussianPlateCompact(String compact) {
  if (compact.length != 9) return false;
  for (var i = 0; i < 9; i++) {
    final c = compact[i];
    if (_slotIsLetter(i)) {
      if (!kRussianPlateLetters.contains(c)) return false;
    } else {
      if (c.compareTo('0') < 0 || c.compareTo('9') > 0) return false;
    }
  }
  return true;
}

/// Поле госномера: только наша клавиатура под полем (read-only для системной клавиатуры).
class RussianLicensePlateField extends StatefulWidget {
  const RussianLicensePlateField({
    super.key,
    required this.controller,
    this.label = 'Гос. номер',
    this.hint = 'А123АА777',
    /// Не null — рамка валидации (зелёный/красный); иначе рамка по фокусу.
    this.validationBorderColor,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final Color? validationBorderColor;

  @override
  State<RussianLicensePlateField> createState() => _RussianLicensePlateFieldState();
}

class _RussianLicensePlateFieldState extends State<RussianLicensePlateField> {
  final FocusNode _focus = FocusNode();

  String get _compact => normalizePlateInput(widget.controller.text);

  void _setCompact(String next) {
    final capped = next.length > 9 ? next.substring(0, 9) : next;
    widget.controller.value = TextEditingValue(
      text: capped,
      selection: TextSelection.collapsed(offset: capped.length),
    );
    setState(() {});
  }

  void _onKeyLetter(String letter) {
    final t = _compact;
    if (t.length >= 9) return;
    if (!_slotIsLetter(t.length)) return;
    _setCompact(t + letter);
  }

  void _onKeyDigit(String d) {
    final t = _compact;
    if (t.length >= 9) return;
    if (_slotIsLetter(t.length)) return;
    _setCompact(t + d);
  }

  void _onBackspace() {
    final t = _compact;
    if (t.isEmpty) return;
    _setCompact(t.substring(0, t.length - 1));
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onCtrl);
  }

  void _onCtrl() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_onCtrl);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _compact;
    final needLetter = t.length < 9 && _slotIsLetter(t.length);
    final needDigit = t.length < 9 && !needLetter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: TextStyle(fontSize: 14, color: context.palette.textSecondary)),
        SizedBox(height: 4),
        Text(
          'Формат: буква · 3 цифры · 2 буквы · 3 цифры (буквы: $kRussianPlateLetters)',
          style: TextStyle(fontSize: 11, color: context.palette.textTertiary),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: context.palette.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.validationBorderColor ??
                  (_focus.hasFocus ? context.palette.primary : context.palette.border),
              width: widget.validationBorderColor != null ? 1.5 : 1,
            ),
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            readOnly: true,
            showCursor: true,
            enableInteractiveSelection: false,
            keyboardType: TextInputType.none,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.palette.textPrimary,
              letterSpacing: 2,
            ),
            onTap: () => _focus.requestFocus(),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(color: context.palette.textPlaceholder, letterSpacing: 2),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        SizedBox(height: 12),
        Text(
          needLetter
              ? 'Выберите букву'
              : (needDigit ? 'Выберите цифру' : (t.length == 9 ? 'Номер введён полностью' : '')),
          style: TextStyle(fontSize: 12, color: needLetter || needDigit ? context.palette.primary : context.palette.textTertiary),
        ),
        SizedBox(height: 8),
        // Отдельная строка «Стереть» — доступна при любом непустом номере (и после букв, и после цифр).
        if (t.isNotEmpty) ...[
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _onBackspace,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.palette.nestedBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.palette.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.backspace_outlined, size: 18, color: context.palette.textPrimary.withValues(alpha: 0.9)),
                    SizedBox(width: 8),
                    Text(
                      'Стереть символ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.palette.textPrimary.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 8),
        ],
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final letter in kRussianPlateLetters.split(''))
              _KeyChip(
                label: letter,
                enabled: needLetter,
                onTap: () => _onKeyLetter(letter),
              ),
          ],
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'])
              _KeyChip(
                label: d,
                enabled: needDigit,
                onTap: () => _onKeyDigit(d),
              ),
          ],
        ),
      ],
    );
  }
}

class _KeyChip extends StatelessWidget {
  const _KeyChip({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 40,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? context.palette.nestedBg : context.palette.nestedBg.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: enabled ? context.palette.border : context.palette.border.withValues(alpha: 0.3)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: label == '⌫' ? 18 : 16,
              fontWeight: FontWeight.w600,
              color: enabled ? context.palette.textPrimary : context.palette.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}
