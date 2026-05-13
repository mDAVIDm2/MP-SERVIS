import '../l10n/app_l10n.dart';
import 'car_expense_group_ids.dart';

/// Статус синхронизации ручной записи с MP-Servis.
enum CarManualExpenseSyncStatus {
  synced,
  pendingCreate,
  pendingUpdate,
  pendingDelete,
  failed,
}

/// Вид топлива при ручной записи заправки.
enum CarManualFuelType {
  ai92,
  ai95,
  ai98,
  ai100,
  diesel,
  dieselPlus,
  methane,
  propane,
  lpg,
  electric,
  otherFuel,
}

extension CarManualFuelTypeL10n on CarManualFuelType {
  String label(AppL10n l10n) {
    if (l10n.isEn) {
      return switch (this) {
        CarManualFuelType.ai92 => 'AI-92',
        CarManualFuelType.ai95 => 'AI-95',
        CarManualFuelType.ai98 => 'AI-98',
        CarManualFuelType.ai100 => 'AI-100',
        CarManualFuelType.diesel => 'Diesel',
        CarManualFuelType.dieselPlus => 'Diesel+',
        CarManualFuelType.methane => 'CNG (methane)',
        CarManualFuelType.propane => 'Propane (GLP)',
        CarManualFuelType.lpg => 'LPG',
        CarManualFuelType.electric => 'Electric (kWh)',
        CarManualFuelType.otherFuel => 'Other fuel',
      };
    }
    return switch (this) {
      CarManualFuelType.ai92 => 'АИ-92',
      CarManualFuelType.ai95 => 'АИ-95',
      CarManualFuelType.ai98 => 'АИ-98',
      CarManualFuelType.ai100 => 'АИ-100',
      CarManualFuelType.diesel => 'ДТ',
      CarManualFuelType.dieselPlus => 'ДТ+',
      CarManualFuelType.methane => 'Метан (КПГ)',
      CarManualFuelType.propane => 'Пропан',
      CarManualFuelType.lpg => 'Газ (ГБО)',
      CarManualFuelType.electric => 'Электро',
      CarManualFuelType.otherFuel => 'Другое топливо',
    };
  }
}

/// Пресет «мелкого» расхода (альтернатива свободному названию).
class CarConsumablePreset {
  const CarConsumablePreset({
    required this.id,
    required this.titleRu,
    required this.titleEn,
  });
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

CarManualExpenseKind carManualExpenseKindFromServer(String? kn) {
  if (kn == null || kn.isEmpty) return CarManualExpenseKind.custom;
  for (final v in CarManualExpenseKind.values) {
    if (v.name == kn) return v;
  }
  if (kn == 'consumable_preset') return CarManualExpenseKind.consumablePreset;
  if (kn == 'service') return CarManualExpenseKind.custom;
  return CarManualExpenseKind.custom;
}

CarManualExpenseSyncStatus? carManualExpenseSyncStatusFromJson(dynamic v) {
  if (v is! String || v.isEmpty) return null;
  for (final s in CarManualExpenseSyncStatus.values) {
    if (s.name == v) return s;
  }
  return null;
}

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
    this.fuelStationName,
    this.placeName,
    this.fullTank,
    this.expenseCategoryId,
    this.expenseItemTitle,
    this.analyticsOperationName,
    this.serverId,
    this.clientRecordId,
    this.syncStatus,
    this.serverUpdatedAt,
    this.localUpdatedAt,
    this.deletedAt,
    this.lastSyncError,
  });

  final String id;
  final String carId;
  final DateTime date;
  final int priceKopecks;
  final CarManualExpenseKind kind;
  final CarManualFuelType? fuelType;
  final double? liters;
  final int? pricePerLiterKopecks;
  final int? odometerKm;
  final String? presetId;
  final String? customTitle;
  final String? note;
  final String? expenseGroupId;
  final String? expenseSubId;
  final int? materialPriceKopecks;
  final int? laborPriceKopecks;
  final String? fuelStationName;
  final String? placeName;
  final bool? fullTank;
  final String? expenseCategoryId;
  final String? expenseItemTitle;
  final String? analyticsOperationName;

  final String? serverId;

  /// Если задан — дублирует стабильный локальный ключ для API; иначе в API уходит [id].
  final String? clientRecordId;
  final CarManualExpenseSyncStatus? syncStatus;
  final DateTime? serverUpdatedAt;
  final DateTime? localUpdatedAt;
  final DateTime? deletedAt;
  final String? lastSyncError;

  String get effectiveClientRecordId =>
      (clientRecordId != null && clientRecordId!.trim().isNotEmpty)
      ? clientRecordId!.trim()
      : id;

  bool get isHiddenFromAnalytics =>
      syncStatus == CarManualExpenseSyncStatus.pendingDelete ||
      deletedAt != null;

  /// Иконки в журнале: не показываем для [synced] и «тихого» null (до миграции).
  CarManualExpenseSyncStatus? get syncStatusForAnalytics {
    final s = syncStatus;
    if (s == null || s == CarManualExpenseSyncStatus.synced) return null;
    return s;
  }

  bool get isDirtyForSync {
    if (isHiddenFromAnalytics) return true;
    final s = syncStatus;
    return s == null ||
        s == CarManualExpenseSyncStatus.pendingCreate ||
        s == CarManualExpenseSyncStatus.pendingUpdate ||
        s == CarManualExpenseSyncStatus.failed;
  }

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
      if (gid == CarExpenseGroupIds.unplanned &&
          (expenseGroupId == null || expenseGroupId!.trim().isEmpty)) {
        return l10n.isEn ? 'Other: $detail' : 'Прочее: $detail';
      }
      return '$g · $detail';
    }
    return g;
  }

  CarManualExpenseRecord copyWith({
    String? id,
    String? carId,
    DateTime? date,
    int? priceKopecks,
    CarManualExpenseKind? kind,
    CarManualFuelType? fuelType,
    double? liters,
    int? pricePerLiterKopecks,
    int? odometerKm,
    String? presetId,
    String? customTitle,
    String? note,
    String? expenseGroupId,
    String? expenseSubId,
    int? materialPriceKopecks,
    int? laborPriceKopecks,
    String? fuelStationName,
    String? placeName,
    bool? fullTank,
    String? expenseCategoryId,
    String? expenseItemTitle,
    String? analyticsOperationName,
    String? serverId,
    String? clientRecordId,
    CarManualExpenseSyncStatus? syncStatus,
    DateTime? serverUpdatedAt,
    DateTime? localUpdatedAt,
    DateTime? deletedAt,
    String? lastSyncError,
  }) {
    return CarManualExpenseRecord(
      id: id ?? this.id,
      carId: carId ?? this.carId,
      date: date ?? this.date,
      priceKopecks: priceKopecks ?? this.priceKopecks,
      kind: kind ?? this.kind,
      fuelType: fuelType ?? this.fuelType,
      liters: liters ?? this.liters,
      pricePerLiterKopecks: pricePerLiterKopecks ?? this.pricePerLiterKopecks,
      odometerKm: odometerKm ?? this.odometerKm,
      presetId: presetId ?? this.presetId,
      customTitle: customTitle ?? this.customTitle,
      note: note ?? this.note,
      expenseGroupId: expenseGroupId ?? this.expenseGroupId,
      expenseSubId: expenseSubId ?? this.expenseSubId,
      materialPriceKopecks: materialPriceKopecks ?? this.materialPriceKopecks,
      laborPriceKopecks: laborPriceKopecks ?? this.laborPriceKopecks,
      fuelStationName: fuelStationName ?? this.fuelStationName,
      placeName: placeName ?? this.placeName,
      fullTank: fullTank ?? this.fullTank,
      expenseCategoryId: expenseCategoryId ?? this.expenseCategoryId,
      expenseItemTitle: expenseItemTitle ?? this.expenseItemTitle,
      analyticsOperationName:
          analyticsOperationName ?? this.analyticsOperationName,
      serverId: serverId ?? this.serverId,
      clientRecordId: clientRecordId ?? this.clientRecordId,
      syncStatus: syncStatus ?? this.syncStatus,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      lastSyncError: lastSyncError ?? this.lastSyncError,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'carId': carId,
    'date': date.toIso8601String(),
    'priceKopecks': priceKopecks,
    'kind': kind.name,
    if (fuelType != null) 'fuelType': fuelType!.name,
    if (liters != null) 'liters': liters,
    if (pricePerLiterKopecks != null)
      'pricePerLiterKopecks': pricePerLiterKopecks,
    if (odometerKm != null) 'odometerKm': odometerKm,
    if (presetId != null) 'presetId': presetId,
    if (customTitle != null) 'customTitle': customTitle,
    if (note != null && note!.isNotEmpty) 'note': note,
    if (expenseGroupId != null && expenseGroupId!.trim().isNotEmpty)
      'expenseGroupId': expenseGroupId,
    if (expenseSubId != null && expenseSubId!.trim().isNotEmpty)
      'expenseSubId': expenseSubId,
    if (materialPriceKopecks != null)
      'materialPriceKopecks': materialPriceKopecks,
    if (laborPriceKopecks != null) 'laborPriceKopecks': laborPriceKopecks,
    if (fuelStationName != null && fuelStationName!.trim().isNotEmpty)
      'fuelStationName': fuelStationName,
    if (placeName != null && placeName!.trim().isNotEmpty)
      'placeName': placeName,
    if (fullTank != null) 'fullTank': fullTank,
    if (expenseCategoryId != null && expenseCategoryId!.trim().isNotEmpty)
      'expenseCategoryId': expenseCategoryId,
    if (expenseItemTitle != null && expenseItemTitle!.trim().isNotEmpty)
      'expenseItemTitle': expenseItemTitle,
    if (analyticsOperationName != null &&
        analyticsOperationName!.trim().isNotEmpty)
      'analyticsOperationName': analyticsOperationName,
    if (serverId != null && serverId!.isNotEmpty) 'serverId': serverId,
    if (clientRecordId != null && clientRecordId!.trim().isNotEmpty)
      'clientRecordId': clientRecordId,
    if (syncStatus != null) 'syncStatus': syncStatus!.name,
    if (serverUpdatedAt != null)
      'serverUpdatedAt': serverUpdatedAt!.toIso8601String(),
    if (localUpdatedAt != null)
      'localUpdatedAt': localUpdatedAt!.toIso8601String(),
    if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
    if (lastSyncError != null && lastSyncError!.isNotEmpty)
      'lastSyncError': lastSyncError,
  };

  static CarManualExpenseRecord? fromJson(Map<String, dynamic> m) {
    try {
      final id = m['id'] as String?;
      final carId = m['carId'] as String?;
      if (id == null || id.isEmpty || carId == null || carId.isEmpty) {
        return null;
      }
      final dateStr = m['date'] as String?;
      final d = dateStr == null ? null : DateTime.tryParse(dateStr);
      if (d == null) return null;
      CarManualExpenseKind? k;
      final kn = m['kind'] as String?;
      k = carManualExpenseKindFromServer(kn);
      final price = (m['priceKopecks'] as num?)?.toInt() ?? 0;
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
        odometerKm: (m['odometerKm'] as num?)?.toInt(),
        presetId: m['presetId'] as String?,
        customTitle: m['customTitle'] as String?,
        note: m['note'] as String?,
        expenseGroupId: m['expenseGroupId'] as String?,
        expenseSubId: m['expenseSubId'] as String?,
        materialPriceKopecks: (m['materialPriceKopecks'] as num?)?.toInt(),
        laborPriceKopecks: (m['laborPriceKopecks'] as num?)?.toInt(),
        fuelStationName: m['fuelStationName'] as String?,
        placeName: m['placeName'] as String?,
        fullTank: m['fullTank'] as bool?,
        expenseCategoryId: m['expenseCategoryId'] as String?,
        expenseItemTitle: m['expenseItemTitle'] as String?,
        analyticsOperationName: m['analyticsOperationName'] as String?,
        serverId: m['serverId'] as String?,
        clientRecordId: m['clientRecordId'] as String?,
        syncStatus: carManualExpenseSyncStatusFromJson(m['syncStatus']),
        serverUpdatedAt: _parseDt(m['serverUpdatedAt']),
        localUpdatedAt: _parseDt(m['localUpdatedAt']),
        deletedAt: _parseDt(m['deletedAt']),
        lastSyncError: m['lastSyncError'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  static DateTime? _parseDt(dynamic v) {
    if (v is! String || v.isEmpty) return null;
    return DateTime.tryParse(v);
  }

  /// Ответ сервера (GET/PUT/sync item).
  static CarManualExpenseRecord? fromServerItemMap(
    Map<String, dynamic> m, {
    required String fallbackCarId,
  }) {
    try {
      final clientRecordId = (m['clientRecordId'] as String?)?.trim();
      if (clientRecordId == null || clientRecordId.isEmpty) return null;
      final carId = (m['carId'] as String?)?.trim();
      final cid = (carId != null && carId.isNotEmpty) ? carId : fallbackCarId;
      final dateStr = m['date'] as String?;
      final d = dateStr == null ? null : DateTime.tryParse(dateStr);
      if (d == null) return null;
      final price = (m['priceKopecks'] as num?)?.toInt() ?? 0;
      if (price <= 0) return null;
      final kind = carManualExpenseKindFromServer(m['kind'] as String?);
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
      final delAt = _parseDt(m['deletedAt']);
      final srvUp = _parseDt(m['serverUpdatedAt']);
      final litersVal = m['fuelLiters'] ?? m['liters'];
      return CarManualExpenseRecord(
        id: clientRecordId,
        carId: cid,
        date: d,
        priceKopecks: price,
        kind: kind,
        fuelType: ft,
        liters: (litersVal as num?)?.toDouble(),
        pricePerLiterKopecks:
            (m['fuelPricePerLiterKopecks'] as num?)?.toInt() ??
            (m['pricePerLiterKopecks'] as num?)?.toInt(),
        odometerKm: (m['odometerKm'] as num?)?.toInt(),
        presetId: m['presetId'] as String?,
        customTitle: m['customTitle'] as String?,
        note: m['note'] as String?,
        expenseGroupId: m['expenseGroupId'] as String?,
        expenseSubId: m['expenseSubId'] as String?,
        materialPriceKopecks: (m['materialPriceKopecks'] as num?)?.toInt(),
        laborPriceKopecks: (m['laborPriceKopecks'] as num?)?.toInt(),
        fuelStationName: m['fuelStationName'] as String?,
        placeName: m['placeName'] as String?,
        fullTank: m['fullTank'] as bool?,
        expenseCategoryId: m['expenseCategoryId'] as String?,
        expenseItemTitle: m['expenseItemTitle'] as String?,
        analyticsOperationName: m['analyticsOperationName'] as String?,
        serverId: m['serverId'] as String?,
        clientRecordId: clientRecordId,
        syncStatus: CarManualExpenseSyncStatus.synced,
        serverUpdatedAt: srvUp,
        localUpdatedAt: _parseDt(m['clientUpdatedAt']) ?? srvUp,
        deletedAt: delAt,
        lastSyncError: null,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toUpsertRequestBody({String? deviceId}) {
    return <String, dynamic>{
      'date': date.toUtc().toIso8601String(),
      'kind': kind.name,
      'priceKopecks': priceKopecks,
      if (fuelType != null) 'fuelType': fuelType!.name,
      if (liters != null) 'fuelLiters': liters,
      if (pricePerLiterKopecks != null)
        'fuelPricePerLiterKopecks': pricePerLiterKopecks,
      if (odometerKm != null) 'odometerKm': odometerKm,
      if (fuelStationName != null && fuelStationName!.trim().isNotEmpty)
        'fuelStationName': fuelStationName!.trim(),
      if (fullTank != null) 'fullTank': fullTank,
      if (presetId != null) 'presetId': presetId,
      if (customTitle != null && customTitle!.trim().isNotEmpty)
        'customTitle': customTitle!.trim(),
      if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
      if (expenseGroupId != null && expenseGroupId!.trim().isNotEmpty)
        'expenseGroupId': expenseGroupId!.trim(),
      if (expenseSubId != null && expenseSubId!.trim().isNotEmpty)
        'expenseSubId': expenseSubId!.trim(),
      if (expenseCategoryId != null && expenseCategoryId!.trim().isNotEmpty)
        'expenseCategoryId': expenseCategoryId!.trim(),
      if (expenseItemTitle != null && expenseItemTitle!.trim().isNotEmpty)
        'expenseItemTitle': expenseItemTitle!.trim(),
      if (analyticsOperationName != null &&
          analyticsOperationName!.trim().isNotEmpty)
        'analyticsOperationName': analyticsOperationName!.trim(),
      if (materialPriceKopecks != null)
        'materialPriceKopecks': materialPriceKopecks,
      if (laborPriceKopecks != null) 'laborPriceKopecks': laborPriceKopecks,
      if (placeName != null && placeName!.trim().isNotEmpty)
        'placeName': placeName!.trim(),
      'clientUpdatedAt': (localUpdatedAt ?? date).toUtc().toIso8601String(),
      if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
    };
  }
}

List<CarManualExpenseRecord> visibleCarManualExpenses(
  List<CarManualExpenseRecord> all,
) {
  return all.where((e) => !e.isHiddenFromAnalytics).toList();
}

class CarFuelRefuelStats {
  CarFuelRefuelStats({
    required this.intervals,
    this.medianKopecksPerKm,
    this.usedFullTankIntervals = false,
  });

  final List<
    ({
      CarManualExpenseRecord a,
      CarManualExpenseRecord b,
      double? lPer100,
      int? kopecksPerKm,
    })
  >
  intervals;
  final int? medianKopecksPerKm;
  final bool usedFullTankIntervals;
}

List<CarManualExpenseRecord> _filterFuelByCar(
  List<CarManualExpenseRecord> all,
  String carId, {
  DateTime? fromInclusive,
}) {
  final visible = visibleCarManualExpenses(all);
  var out = visible.where((e) => e.carId == carId && e.isFuel).toList();
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

List<
  ({
    CarManualExpenseRecord a,
    CarManualExpenseRecord b,
    double? lPer100,
    int? kopecksPerKm,
  })
>
_fuelIntervals(List<CarManualExpenseRecord> sortedFuel) {
  final intervals =
      <
        ({
          CarManualExpenseRecord a,
          CarManualExpenseRecord b,
          double? lPer100,
          int? kopecksPerKm,
        })
      >[];
  for (var i = 0; i < sortedFuel.length; i++) {
    final a = i == 0 ? null : sortedFuel[i - 1];
    final b = sortedFuel[i];
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
  return intervals;
}

CarFuelRefuelStats? _statsFromIntervals(
  List<
    ({
      CarManualExpenseRecord a,
      CarManualExpenseRecord b,
      double? lPer100,
      int? kopecksPerKm,
    })
  >
  intervals, {
  bool usedFullTankIntervals = false,
}) {
  if (intervals.isEmpty) return null;
  int? medKpk;
  final kpkList = intervals.map((e) => e.kopecksPerKm).whereType<int>().toList()
    ..sort();
  if (kpkList.isNotEmpty) {
    medKpk = kpkList[kpkList.length ~/ 2];
  }
  return CarFuelRefuelStats(
    intervals: intervals,
    medianKopecksPerKm: medKpk,
    usedFullTankIntervals: usedFullTankIntervals,
  );
}

CarFuelRefuelStats? computeCarFuelRefuelStats(
  List<CarManualExpenseRecord> all,
  String carId, {
  DateTime? fromInclusive,
}) {
  final list = _filterFuelByCar(all, carId, fromInclusive: fromInclusive);
  if (list.length < 2) return null;
  var intervals = _fuelIntervals(list);
  var usedFullTank = false;
  final fullEligible = list
      .where(
        (e) =>
            e.fullTank == true &&
            e.odometerKm != null &&
            e.liters != null &&
            e.liters! > 0,
      )
      .toList();
  if (fullEligible.length >= 2) {
    fullEligible.sort((a, b) {
      final ao = a.odometerKm;
      final bo = b.odometerKm;
      if (ao != null && bo != null && ao != bo) return ao.compareTo(bo);
      return a.date.compareTo(b.date);
    });
    final fullIv = _fuelIntervals(fullEligible);
    if (fullIv.isNotEmpty) {
      intervals = fullIv;
      usedFullTank = true;
    }
  }
  return _statsFromIntervals(intervals, usedFullTankIntervals: usedFullTank);
}

double? computeFuelAveragePricePerLiterRub(
  List<CarManualExpenseRecord> all,
  String carId, {
  DateTime? fromInclusive,
}) {
  final list = _filterFuelByCar(all, carId, fromInclusive: fromInclusive);
  var sumLiters = 0.0;
  var sumKop = 0;
  for (final r in list) {
    final l = r.liters;
    if (l == null || l <= 0) continue;
    if (r.priceKopecks <= 0) continue;
    sumLiters += l;
    sumKop += r.priceKopecks;
  }
  if (sumLiters < 1e-9) return null;
  return (sumKop / 100.0) / sumLiters;
}
