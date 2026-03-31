/// Допустимые буквы госномера РФ (кириллица, как в ГОСТ) — как в клиентском приложении (гараж).
const String kRussianPlateLetters = 'АВЕКМНОРСТУХ';

bool _slotIsLetter(int index) => index == 0 || index == 4 || index == 5;

/// Латиница похожих букв → кириллица, верхний регистр, только цифры и допустимые буквы.
String normalizePlateInput(String raw) {
  const map = {
    'A': 'А',
    'a': 'А',
    'B': 'В',
    'b': 'В',
    'E': 'Е',
    'e': 'Е',
    'K': 'К',
    'k': 'К',
    'M': 'М',
    'm': 'М',
    'H': 'Н',
    'h': 'Н',
    'O': 'О',
    'o': 'О',
    'P': 'Р',
    'p': 'Р',
    'C': 'С',
    'c': 'С',
    'T': 'Т',
    't': 'Т',
    'Y': 'У',
    'y': 'У',
    'X': 'Х',
    'x': 'Х',
    'V': 'В',
    'v': 'В',
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

/// Полный номер: 9 символов, формат буква · 3 цифры · 2 буквы · 3 цифры.
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

/// Результат разбора строки «модель / примечание / госномер» при создании авто.
class ParsedQuickVehicleLine {
  final String carInfo;
  final String? licensePlate;

  const ParsedQuickVehicleLine({required this.carInfo, this.licensePlate});
}

/// Справочная позиция марка+модель (для однозначного сопоставления модели с маркой).
class QuickRefCarPick {
  final int brandId;
  final int modelId;
  final String brandName;
  final String modelName;

  const QuickRefCarPick({
    required this.brandId,
    required this.modelId,
    required this.brandName,
    required this.modelName,
  });

  String get label => '$brandName $modelName';
  String get catalogCarId => 'catalog:$brandId:$modelId';
}

/// Разбор ввода без явных полей марки/модели: вынимает госномер, при однозначной модели подставляет марку.
ParsedQuickVehicleLine parseQuickVehicleFreeLine(String raw, List<QuickRefCarPick> catalog) {
  final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (trimmed.isEmpty) {
    return const ParsedQuickVehicleLine(carInfo: 'Автомобиль');
  }

  final tokens = trimmed.split(' ');
  String? plate;
  final nonPlate = <String>[];
  for (final t in tokens) {
    final c = normalizePlateInput(t);
    if (isValidRussianPlateCompact(c)) {
      plate ??= c;
    } else {
      nonPlate.add(t);
    }
  }

  final remainder = nonPlate.join(' ').trim();
  if (remainder.isEmpty) {
    return ParsedQuickVehicleLine(
      carInfo: plate != null ? 'Автомобиль' : trimmed,
      licensePlate: plate,
    );
  }

  final parts = remainder.split(RegExp(r'\s+'));
  final modelWord = parts[0];
  final brandsForModel = catalog
      .where((p) => p.modelName.toLowerCase() == modelWord.toLowerCase())
      .map((p) => p.brandName)
      .toSet()
      .toList();

  if (brandsForModel.length == 1) {
    final rest = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    final name = rest.isEmpty ? '${brandsForModel[0]} $modelWord' : '${brandsForModel[0]} $modelWord $rest';
    return ParsedQuickVehicleLine(carInfo: name, licensePlate: plate);
  }

  return ParsedQuickVehicleLine(carInfo: remainder, licensePlate: plate);
}

/// Сборка итогового описания и госномера с учётом структурированных полей и явного госномера в форме.
ParsedQuickVehicleLine composeNewVehicleForOrder({
  required bool structured,
  required String brand,
  required String model,
  required String generation,
  required String freeLine,
  required String explicitPlateRaw,
  required List<QuickRefCarPick> catalog,
}) {
  final exp = normalizePlateInput(explicitPlateRaw.trim());
  final explicitOk = isValidRussianPlateCompact(exp);

  if (structured) {
    final b = brand.trim();
    final m = model.trim();
    final g = generation.trim();
    final headParts = <String>[];
    if (b.isNotEmpty) headParts.add(b);
    if (m.isNotEmpty) headParts.add(m);
    if (g.isNotEmpty) headParts.add(g);
    final head = headParts.join(' ');

    final extra = freeLine.trim();
    if (extra.isEmpty) {
      return ParsedQuickVehicleLine(
        carInfo: head.isEmpty ? 'Автомобиль' : head,
        licensePlate: explicitOk ? exp : null,
      );
    }

    final extraParsed = parseQuickVehicleFreeLine(extra, catalog);
    final plate = explicitOk ? exp : extraParsed.licensePlate;
    var name = head.isEmpty ? extraParsed.carInfo : '$head ${extraParsed.carInfo}'.trim();
    if (extraParsed.carInfo == 'Автомобиль' && head.isNotEmpty) {
      name = head;
    }
    return ParsedQuickVehicleLine(carInfo: name, licensePlate: plate);
  }

  final u = parseQuickVehicleFreeLine(freeLine.trim(), catalog);
  if (explicitOk) {
    return ParsedQuickVehicleLine(carInfo: u.carInfo, licensePlate: u.licensePlate ?? exp);
  }
  return u;
}
