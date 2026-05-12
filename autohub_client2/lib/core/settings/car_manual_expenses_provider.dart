import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_provider.dart' show authProvider, sharedPreferencesProvider;
import '../l10n/app_l10n.dart';
import 'car_expense_group_ids.dart';

const _kCarManualExpensesPrefix = 'car_manual_expenses_';

/// Вид топлива при ручной записи заправки.
enum CarManualFuelType {
  ai92,
  ai95,
  ai98,
  diesel,
  dieselPlus,
  methane,
  propane,
  lpg,
}

extension CarManualFuelTypeL10n on CarManualFuelType {
  String label(AppL10n l10n) {
    if (l10n.isEn) {
      return switch (this) {
        CarManualFuelType.ai92 => 'AI-92',
        CarManualFuelType.ai95 => 'AI-95',
        CarManualFuelType.ai98 => 'AI-98',
        CarManualFuelType.diesel => 'Diesel',
        CarManualFuelType.dieselPlus => 'Diesel+',
        CarManualFuelType.methane => 'CNG (methane)',
        CarManualFuelType.propane => 'Propane (GLP)',
        CarManualFuelType.lpg => 'LPG',
      };
    }
    return switch (this) {
      CarManualFuelType.ai92 => 'АИ-92',
      CarManualFuelType.ai95 => 'АИ-95',
      CarManualFuelType.ai98 => 'АИ-98',
      CarManualFuelType.diesel => 'ДТ',
      CarManualFuelType.dieselPlus => 'ДТ+',
      CarManualFuelType.methane => 'Метан (КПГ)',
      CarManualFuelType.propane => 'Пропан',
      CarManualFuelType.lpg => 'Газ (ГБО)',
    };
  }
}

/// Пресет «мелкого» расхода (альтернатива свободному названию).
class CarConsumablePreset {
  const CarConsumablePreset({required this.id, required this.titleRu, required this.titleEn});
  final String id;
  final String titleRu;
  final String titleEn;

  String title(AppL10n l10n) => l10n.isEn ? titleEn : titleRu;
}

const kCarConsumablePresets = <CarConsumablePreset>[
  CarConsumablePreset(
    id: 'wiper',
    titleRu: 'Щётки стеклоочистителя',
    titleEn: 'Wiper blades',
  ),
  CarConsumablePreset(
    id: 'lamps',
    titleRu: 'Автолампы / освещение',
    titleEn: 'Bulbs / lighting',
  ),
  CarConsumablePreset(
    id: 'washer',
    titleRu: 'Омыватель / незамерзайка',
    titleEn: 'Washer fluid',
  ),
  CarConsumablePreset(
    id: 'tires_repair',
    titleRu: 'Ремонт / подкачка шин',
    titleEn: 'Tire repair / inflation',
  ),
  CarConsumablePreset(
    id: 'cosmetic',
    titleRu: 'Автохимия, салон',
    titleEn: 'Detailing / cabin care',
  ),
];

/// Ручная запись: заправка или иной расход.
enum CarManualExpenseKind { fuel, consumablePreset, custom }

class CarManualExpenseRecord {
  const CarManualExpenseRecord({
    required this.id,
    required this.carId,
    required this.date,
    required this.priceKopecks,
    required this.kind,
    this.fuelType,
    this.liters,
    this.pricePerLiterKopecks,
    this.odometerKm,
    this.presetId,
    this.customTitle,
    this.note,
    this.expenseGroupId,
    this.expenseSubId,
    this.materialPriceKopecks,
    this.laborPriceKopecks,
  });

  final String id;
  final String carId;
  final DateTime date;
  final int priceKopecks;
  final CarManualExpenseKind kind;
  final CarManualFuelType? fuelType;
  final double? liters;
  /// Копейки за литр (удобно для отображения и обратной синхронизации в форме).
  final int? pricePerLiterKopecks;
  final int? odometerKm;
  final String? presetId;
  final String? customTitle;
  final String? note;
  /// [CarExpenseGroupIds] — для не-топлива; у старых записей null (выводится эвристика).
  final String? expenseGroupId;
  final String? expenseSubId;
  final int? materialPriceKopecks;
  final int? laborPriceKopecks;

  bool get isFuel => kind == CarManualExpenseKind.fuel;

  static String? _inferGroupIdLegacy(CarManualExpenseRecord r) {
    if (r.isFuel) return CarExpenseGroupIds.fuel;
    if (r.kind == CarManualExpenseKind.consumablePreset) {
      switch (r.presetId) {
        case 'wiper':
        case 'washer':
        case 'cosmetic':
          return CarExpenseGroupIds.cleanComfort;
        case 'lamps':
          return CarExpenseGroupIds.accessories;
        case 'tires_repair':
          return CarExpenseGroupIds.unplanned;
        default:
          return CarExpenseGroupIds.unplanned;
      }
    }
    return CarExpenseGroupIds.unplanned;
  }

  /// Для аналитики: класс трат с учётом эвристики для старых записей.
  String get resolvedExpenseGroupId {
    if (isFuel) return CarExpenseGroupIds.fuel;
    final g = expenseGroupId?.trim();
    if (g != null && g.isNotEmpty) return g;
    return _inferGroupIdLegacy(this)!;
  }

  String _nonFuelDetailTitle(AppL10n l10n) {
    if (kind == CarManualExpenseKind.consumablePreset) {
      for (final p in kCarConsumablePresets) {
        if (p.id == presetId) return p.title(l10n);
      }
    }
    return (customTitle ?? '').trim();
  }

  String groupLabelAppL10n(AppL10n l10n) {
    if (isFuel) {
      final ft = fuelType;
      if (ft == null) {
        return l10n.isEn ? 'Refuel' : 'Заправка';
      }
      return l10n.isEn
          ? 'Refuel · ${ft.label(l10n)}'
          : 'Заправка · ${ft.label(l10n)}';
    }
    final gid = (expenseGroupId != null && expenseGroupId!.trim().isNotEmpty)
        ? expenseGroupId!.trim()
        : resolvedExpenseGroupId;
    final g = l10n.carExpenseClassGroupTitle(gid);
    final sub = l10n.carExpenseClassSubTitle(expenseSubId);
    final detail = _nonFuelDetailTitle(l10n);
    if (sub != null && detail.isNotEmpty) return '$g · $sub · $detail';
    if (sub != null) return '$g · $sub';
    if (detail.isNotEmpty) {
      if (gid == CarExpenseGroupIds.unplanned && (expenseGroupId == null || expenseGroupId!.trim().isEmpty)) {
        return l10n.isEn ? 'Other: $detail' : 'Прочее: $detail';
      }
      return '$g · $detail';
    }
    return g;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'carId': carId,
        'date': date.toIso8601String(),
        'priceKopecks': priceKopecks,
        'kind': kind.name,
        if (fuelType != null) 'fuelType': fuelType!.name,
        if (liters != null) 'liters': liters,
        if (pricePerLiterKopecks != null) 'pricePerLiterKopecks': pricePerLiterKopecks,
        if (odometerKm != null) 'odometerKm': odometerKm,
        if (presetId != null) 'presetId': presetId,
        if (customTitle != null) 'customTitle': customTitle,
        if (note != null && note!.isNotEmpty) 'note': note,
        if (expenseGroupId != null && expenseGroupId!.trim().isNotEmpty) 'expenseGroupId': expenseGroupId,
        if (expenseSubId != null && expenseSubId!.trim().isNotEmpty) 'expenseSubId': expenseSubId,
        if (materialPriceKopecks != null) 'materialPriceKopecks': materialPriceKopecks,
        if (laborPriceKopecks != null) 'laborPriceKopecks': laborPriceKopecks,
      };

  static CarManualExpenseRecord? fromJson(Map<String, dynamic> m) {
    try {
      final id = m['id'] as String?;
      final carId = m['carId'] as String?;
      if (id == null || id.isEmpty || carId == null || carId.isEmpty) return null;
      final dateStr = m['date'] as String?;
      final d = dateStr == null ? null : DateTime.tryParse(dateStr);
      if (d == null) return null;
      CarManualExpenseKind? k;
      final kn = m['kind'] as String?;
      if (kn != null) {
        for (final v in CarManualExpenseKind.values) {
          if (v.name == kn) {
            k = v;
            break;
          }
        }
      }
      if (k == null) return null;
      final price = m['priceKopecks'] as int? ?? 0;
      if (price <= 0) return null;
      CarManualFuelType? ft;
      final ftn = m['fuelType'] as String?;
      if (ftn != null) {
        for (final t in CarManualFuelType.values) {
          if (t.name == ftn) {
            ft = t;
            break;
          }
        }
      }
      return CarManualExpenseRecord(
        id: id,
        carId: carId,
        date: d,
        priceKopecks: price,
        kind: k,
        fuelType: ft,
        liters: (m['liters'] as num?)?.toDouble(),
        pricePerLiterKopecks: (m['pricePerLiterKopecks'] as num?)?.toInt(),
        odometerKm: m['odometerKm'] as int?,
        presetId: m['presetId'] as String?,
        customTitle: m['customTitle'] as String?,
        note: m['note'] as String?,
        expenseGroupId: m['expenseGroupId'] as String?,
        expenseSubId: m['expenseSubId'] as String?,
        materialPriceKopecks: (m['materialPriceKopecks'] as num?)?.toInt(),
        laborPriceKopecks: (m['laborPriceKopecks'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Сводка по заправкам: расход и цена пути по интервалам (между записями с одометром).
class CarFuelRefuelStats {
  CarFuelRefuelStats({required this.intervals, this.medianKopecksPerKm});

  /// (от предыдущей к следующей) расход л/100км и коп/км, если оба одометра и литры > 0.
  final List<({CarManualExpenseRecord a, CarManualExpenseRecord b, double? lPer100, int? kopecksPerKm})> intervals;
  final int? medianKopecksPerKm;
}

List<CarManualExpenseRecord> _filterFuelByCar(
  List<CarManualExpenseRecord> all,
  String carId, {
  DateTime? fromInclusive,
}) {
  var out = all.where((e) => e.carId == carId && e.isFuel).toList();
  if (fromInclusive != null) {
    out = out.where((e) => !e.date.isBefore(fromInclusive)).toList();
  }
  out.sort((a, b) {
    final ao = a.odometerKm;
    final bo = b.odometerKm;
    if (ao != null && bo != null && ao != bo) return ao.compareTo(bo);
    return a.date.compareTo(b.date);
  });
  return out;
}

/// Рассчитать эвристику расхода: между соседними записями с [odometer], км = b.odometer - a.odometer,
/// условно объём b.liters как израсходовано за интервал.
CarFuelRefuelStats? computeCarFuelRefuelStats(
  List<CarManualExpenseRecord> all,
  String carId, {
  DateTime? fromInclusive,
}) {
  final list = _filterFuelByCar(all, carId, fromInclusive: fromInclusive);
  if (list.length < 2) return null;
  final intervals = <({CarManualExpenseRecord a, CarManualExpenseRecord b, double? lPer100, int? kopecksPerKm})>[];
  for (var i = 0; i < list.length; i++) {
    final a = i == 0 ? null : list[i - 1];
    final b = list[i];
    if (a == null) continue;
    final oa = a.odometerKm;
    final ob = b.odometerKm;
    if (oa == null || ob == null || ob <= oa) continue;
    final km = ob - oa;
    if (km < 1) continue;
    final l = b.liters;
    if (l == null || l <= 0) continue;
    final l100 = l / km * 100.0;
    int? kpk;
    final pay = b.priceKopecks;
    if (pay > 0) {
      kpk = (pay / km).round();
    }
    intervals.add((a: a, b: b, lPer100: l100, kopecksPerKm: kpk));
  }
  if (intervals.isEmpty) return null;
  int? medKpk;
  final kpkList = intervals.map((e) => e.kopecksPerKm).whereType<int>().toList()..sort();
  if (kpkList.isNotEmpty) {
    medKpk = kpkList[kpkList.length ~/ 2];
  }
  return CarFuelRefuelStats(intervals: intervals, medianKopecksPerKm: medKpk);
}

final carManualExpensesProvider =
    StateNotifierProvider<CarManualExpensesNotifier, List<CarManualExpenseRecord>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  final userId = ref.watch(authProvider).user?.id;
  return CarManualExpensesNotifier(prefs, userId);
});

class CarManualExpensesNotifier extends StateNotifier<List<CarManualExpenseRecord>> {
  CarManualExpensesNotifier(this._prefs, this._userId) : super(_load(_prefs, _userId));

  final SharedPreferences? _prefs;
  final String? _userId;

  String get _key => _kCarManualExpensesPrefix + (_userId ?? '');

  static List<CarManualExpenseRecord> _load(SharedPreferences? prefs, String? userId) {
    if (prefs == null || userId == null) return [];
    try {
      final raw = prefs.getString(_kCarManualExpensesPrefix + userId);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>?;
      final out = <CarManualExpenseRecord>[];
      for (final e in list ?? const []) {
        if (e is! Map) continue;
        final r = CarManualExpenseRecord.fromJson(Map<String, dynamic>.from(e));
        if (r != null) out.add(r);
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null || _userId == null) return;
    await p.setString(_key, jsonEncode(state.map((e) => e.toJson()).toList()));
  }

  void add(CarManualExpenseRecord r) {
    state = [...state, r];
    _save();
  }

  void remove(String id) {
    state = state.where((e) => e.id != id).toList();
    _save();
  }

  void removeAllDataForCar(String carId) {
    if (carId.isEmpty) return;
    state = state.where((e) => e.carId != carId).toList();
    _save();
  }
}

