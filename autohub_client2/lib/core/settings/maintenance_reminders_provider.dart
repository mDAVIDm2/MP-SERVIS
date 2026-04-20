import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_provider.dart' show authProvider, sharedPreferencesProvider;
import '../sync/client_app_state_push_bridge.dart';
import '../../shared/models/car_model.dart';
import '../../shared/models/order_model.dart';

const _kMaintenanceConfigPrefix = 'maintenance_reminder_config_';
const _kMaintenanceRecordsPrefix = 'maintenance_records_';
const _kSyncedOrderIdsPrefix = 'maintenance_synced_order_ids_';

/// Тип обслуживания для напоминания. Масло и масляный фильтр — один пункт (`oil`).
enum MaintenanceType {
  oil('Замена моторного масла и масляного фильтра', 'Две услуги в каталоге, выполняются вместе; один интервал'),
  airFilter('Замена воздушного фильтра', 'По регламенту'),
  antifreeze('Замена антифриза', 'По регламенту'),
  brakes('Тормозные колодки/диски', 'По износу'),
  tires('Шины (сезонная смена)', 'Сезонно'),
  battery('АКБ', 'По состоянию'),
  inspection('Техосмотр', 'Ежегодно'),
  timingBelt('Ремень ГРМ', 'По регламенту'),
  suspension('Подвеска / амортизаторы', 'По износу'),
  sparkPlugs('Свечи зажигания', 'По регламенту'),
  alignment('Развал-схождение', 'При смене шин/подвески'),
  general('ТО общее', 'По регламенту'),
  ;

  final String title;
  final String subtitle;
  const MaintenanceType(this.title, this.subtitle);

  static MaintenanceType? fromTypeKey(String? key) {
    if (key == null || key.isEmpty) return null;
    final k = key == 'oilFilter' ? oil.name : key;
    for (final t in MaintenanceType.values) {
      if (t.name == k) return t;
    }
    return null;
  }

  /// По названию услуги из заказа — масло и масляный фильтр → один тип `oil`.
  static MaintenanceType? fromServiceName(String serviceName) {
    final lower = serviceName.toLowerCase();
    if (lower.contains('масляного фильтра') || (lower.contains('масл') && lower.contains('фильтр'))) {
      return MaintenanceType.oil;
    }
    if (lower.contains('масл')) return MaintenanceType.oil;
    if (lower.contains('воздушного фильтра')) return MaintenanceType.airFilter;
    if (lower.contains('антифриз')) return MaintenanceType.antifreeze;
    if (lower.contains('тормоз') || lower.contains('колодк') || lower.contains('диск')) return MaintenanceType.brakes;
    if (lower.contains('шин') || lower.contains('шины') || lower.contains('резин')) return MaintenanceType.tires;
    if (lower.contains('акб') || lower.contains('батаре')) return MaintenanceType.battery;
    if (lower.contains('техосмотр') || lower.contains('осмотр')) return MaintenanceType.inspection;
    if (lower.contains('грм') || lower.contains('ремн')) return MaintenanceType.timingBelt;
    if (lower.contains('амортизатор') || lower.contains('подвеск')) return MaintenanceType.suspension;
    if (lower.contains('свеч')) return MaintenanceType.sparkPlugs;
    if (lower.contains('развал') || lower.contains('схожден')) return MaintenanceType.alignment;
    if (lower.contains('то ') || lower.contains('техническое обслуживание')) return MaintenanceType.general;
    return null;
  }

  static MaintenanceConfig defaultConfigFor(String carId, MaintenanceType type) {
    final isOil = type == MaintenanceType.oil;
    return MaintenanceConfig(
      carId: carId,
      typeKey: type.name,
      intervalKm: isOil ? 8000 : 15000,
      useKmInterval: true,
      intervalMonths: isOil ? 12 : 0,
      useMonthsInterval: isOil,
      remindEnabled: true,
    );
  }
}

/// Настройка: интервал по км и/или по месяцам (для масла по умолчанию оба).
class MaintenanceConfig {
  final String carId;
  final String typeKey;
  final int intervalKm;
  final bool useKmInterval;
  final int intervalMonths;
  final bool useMonthsInterval;
  final bool remindEnabled;

  const MaintenanceConfig({
    required this.carId,
    required this.typeKey,
    this.intervalKm = 15000,
    this.useKmInterval = true,
    this.intervalMonths = 0,
    this.useMonthsInterval = false,
    this.remindEnabled = true,
  });

  Map<String, dynamic> toJson() => {
        'carId': carId,
        'typeKey': typeKey,
        'intervalKm': intervalKm,
        'useKmInterval': useKmInterval,
        'intervalMonths': intervalMonths,
        'useMonthsInterval': useMonthsInterval,
        'remindEnabled': remindEnabled,
      };

  static MaintenanceConfig fromJson(Map<String, dynamic> map) {
    var typeKey = map['typeKey'] as String? ?? MaintenanceType.oil.name;
    if (typeKey == 'oilFilter') typeKey = MaintenanceType.oil.name;
    final isOil = typeKey == MaintenanceType.oil.name;
    final legacyKm = (map['intervalKm'] as num?)?.toInt() ?? (isOil ? 8000 : 15000);
    final useKm = map['useKmInterval'] as bool? ?? true;
    final rawMonths = (map['intervalMonths'] as num?)?.toInt();
    var useMonths = map['useMonthsInterval'] as bool?;
    if (useMonths == null) {
      useMonths = isOil ? true : (rawMonths != null && rawMonths > 0);
    }
    final months = rawMonths ?? (isOil && useMonths ? 12 : 0);
    return MaintenanceConfig(
      carId: map['carId'] as String? ?? '',
      typeKey: typeKey,
      intervalKm: legacyKm.clamp(1, 500000),
      useKmInterval: useKm,
      intervalMonths: months.clamp(0, 120),
      useMonthsInterval: useMonths,
      remindEnabled: map['remindEnabled'] as bool? ?? true,
    );
  }
}

class MaintenanceRecord {
  final String id;
  final String carId;
  final String typeKey;
  final int odometerKm;
  final DateTime date;
  final String? place;
  final String? orderId;

  const MaintenanceRecord({
    required this.id,
    required this.carId,
    required this.typeKey,
    required this.odometerKm,
    required this.date,
    this.place,
    this.orderId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'carId': carId,
        'typeKey': typeKey,
        'odometerKm': odometerKm,
        'date': date.millisecondsSinceEpoch,
        'place': place,
        'orderId': orderId,
      };

  static MaintenanceRecord fromJson(Map<String, dynamic> map) {
    var tk = map['typeKey'] as String? ?? MaintenanceType.oil.name;
    if (tk == 'oilFilter') tk = MaintenanceType.oil.name;
    return MaintenanceRecord(
      id: map['id'] as String? ?? '${map['date']}_${map['carId']}_$tk',
      carId: map['carId'] as String? ?? '',
      typeKey: tk,
      odometerKm: (map['odometerKm'] as num?)?.toInt() ?? 0,
      date: DateTime.fromMillisecondsSinceEpoch((map['date'] as num?)?.toInt() ?? 0),
      place: map['place'] as String?,
      orderId: map['orderId'] as String?,
    );
  }
}

class MaintenanceRemindersState {
  final List<MaintenanceConfig> configs;
  final List<MaintenanceRecord> records;
  final Set<String> syncedOrderIds;

  const MaintenanceRemindersState({
    this.configs = const [],
    this.records = const [],
    this.syncedOrderIds = const {},
  });
}

/// Снимок для UI: последняя замена, остаток, срок, полоса прогресса.
class MaintenanceDueSnapshot {
  const MaintenanceDueSnapshot({
    required this.hasConfig,
    required this.remindEnabled,
    this.lastRecord,
    this.nextDueKm,
    this.nextDueDate,
    this.kmRemaining,
    this.daysRemaining,
    this.progress01 = 0,
    this.overdue = false,
    this.overdueByKm = false,
    this.overdueByDate = false,
  });

  final bool hasConfig;
  final bool remindEnabled;
  final MaintenanceRecord? lastRecord;
  final int? nextDueKm;
  final DateTime? nextDueDate;
  final int? kmRemaining;
  final int? daysRemaining;
  final double progress01;
  final bool overdue;
  final bool overdueByKm;
  final bool overdueByDate;

  static MaintenanceDueSnapshot empty() => const MaintenanceDueSnapshot(hasConfig: false, remindEnabled: true);
}

final availableMaintenanceTypesProvider = Provider<List<MaintenanceType>>((ref) {
  return MaintenanceType.values.toList();
});

final maintenanceRemindersProvider =
    StateNotifierProvider<MaintenanceRemindersNotifier, MaintenanceRemindersState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  final userId = ref.watch(authProvider).user?.id;
  return MaintenanceRemindersNotifier(prefs, userId);
});

class MaintenanceRemindersNotifier extends StateNotifier<MaintenanceRemindersState> {
  MaintenanceRemindersNotifier(this._prefs, this._userId)
      : super(_initialState(_prefs, _userId)) {
    if (_prefs != null && _userId != null) {
      Future.microtask(() => _save());
    }
  }

  final SharedPreferences? _prefs;
  final String? _userId;

  static MaintenanceRemindersState _initialState(SharedPreferences? prefs, String? userId) {
    var configs = _loadConfigs(prefs, userId);
    var records = _loadRecords(prefs, userId);
    final synced = _loadSyncedOrderIds(prefs, userId);
    configs = _migrateAndDedupeConfigs(configs);
    records = _migrateRecords(records);
    return MaintenanceRemindersState(configs: configs, records: records, syncedOrderIds: synced);
  }

  String get _keyConfig => _kMaintenanceConfigPrefix + (_userId ?? '');
  String get _keyRecords => _kMaintenanceRecordsPrefix + (_userId ?? '');
  String get _keySynced => _kSyncedOrderIdsPrefix + (_userId ?? '');

  static List<MaintenanceConfig> _loadConfigs(SharedPreferences? prefs, String? userId) {
    if (prefs == null || userId == null) return [];
    try {
      final raw = prefs.getString(_kMaintenanceConfigPrefix + userId);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>?;
      return list?.map((e) => MaintenanceConfig.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    } catch (_) {
      return [];
    }
  }

  static List<MaintenanceRecord> _loadRecords(SharedPreferences? prefs, String? userId) {
    if (prefs == null || userId == null) return [];
    try {
      final raw = prefs.getString(_kMaintenanceRecordsPrefix + userId);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>?;
      return list?.map((e) => MaintenanceRecord.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    } catch (_) {
      return [];
    }
  }

  static Set<String> _loadSyncedOrderIds(SharedPreferences? prefs, String? userId) {
    if (prefs == null || userId == null) return {};
    try {
      final raw = prefs.getString(_kSyncedOrderIdsPrefix + userId);
      if (raw == null || raw.isEmpty) return {};
      final list = jsonDecode(raw) as List<dynamic>?;
      return list?.map((e) => e as String).toSet() ?? {};
    } catch (_) {
      return {};
    }
  }

  /// Объединяем старые `oil` + `oilFilter` в одну конфигурацию на авто (мин. км = чаще).
  static List<MaintenanceConfig> _migrateAndDedupeConfigs(List<MaintenanceConfig> list) {
    final map = <String, MaintenanceConfig>{};
    for (final c in list) {
      final tk = c.typeKey == 'oilFilter' ? MaintenanceType.oil.name : c.typeKey;
      final n = MaintenanceConfig(
        carId: c.carId,
        typeKey: tk,
        intervalKm: c.intervalKm.clamp(1, 500000),
        useKmInterval: c.useKmInterval,
        intervalMonths: c.intervalMonths.clamp(0, 120),
        useMonthsInterval: c.useMonthsInterval,
        remindEnabled: c.remindEnabled,
      );
      final key = '${n.carId}|${n.typeKey}';
      final ex = map[key];
      if (ex == null) {
        map[key] = n;
      } else {
        map[key] = MaintenanceConfig(
          carId: ex.carId,
          typeKey: ex.typeKey,
          intervalKm: math.min(ex.intervalKm, n.intervalKm).clamp(1, 500000),
          useKmInterval: ex.useKmInterval || n.useKmInterval,
          intervalMonths: math.max(ex.intervalMonths, n.intervalMonths).clamp(0, 120),
          useMonthsInterval: ex.useMonthsInterval || n.useMonthsInterval,
          remindEnabled: ex.remindEnabled || n.remindEnabled,
        );
      }
    }
    return map.values.map((c) {
      if (c.typeKey != MaintenanceType.oil.name) return c;
      if (c.useMonthsInterval && c.intervalMonths < 1) {
        return MaintenanceConfig(
          carId: c.carId,
          typeKey: c.typeKey,
          intervalKm: c.intervalKm,
          useKmInterval: c.useKmInterval,
          intervalMonths: 12,
          useMonthsInterval: true,
          remindEnabled: c.remindEnabled,
        );
      }
      return c;
    }).toList();
  }

  static List<MaintenanceRecord> _migrateRecords(List<MaintenanceRecord> list) {
    final seenOrderOil = <String>{};
    final out = <MaintenanceRecord>[];
    for (final r in list) {
      var tk = r.typeKey == 'oilFilter' ? MaintenanceType.oil.name : r.typeKey;
      if (tk == MaintenanceType.oil.name && r.orderId != null && r.orderId!.isNotEmpty) {
        final k = '${r.carId}|${r.orderId}';
        if (seenOrderOil.contains(k)) continue;
        seenOrderOil.add(k);
      }
      if (tk != r.typeKey) {
        out.add(MaintenanceRecord(
          id: r.id,
          carId: r.carId,
          typeKey: tk,
          odometerKm: r.odometerKm,
          date: r.date,
          place: r.place,
          orderId: r.orderId,
        ));
      } else {
        out.add(r);
      }
    }
    return out;
  }

  Future<void> _save() async {
    final prefs = _prefs;
    if (prefs == null || _userId == null) return;
    await prefs.setString(_keyConfig, jsonEncode(state.configs.map((e) => e.toJson()).toList()));
    await prefs.setString(_keyRecords, jsonEncode(state.records.map((e) => e.toJson()).toList()));
    await prefs.setString(_keySynced, jsonEncode(state.syncedOrderIds.toList()));
    scheduleClientAppStatePush();
  }

  static bool _sameLogicalType(String typeKeyA, String typeKeyB) {
    final a = typeKeyA == 'oilFilter' ? MaintenanceType.oil.name : typeKeyA;
    final b = typeKeyB == 'oilFilter' ? MaintenanceType.oil.name : typeKeyB;
    return a == b;
  }

  MaintenanceConfig? getConfig(String carId, String typeKey) {
    try {
      return state.configs.firstWhere((c) => c.carId == carId && _sameLogicalType(c.typeKey, typeKey));
    } catch (_) {
      return null;
    }
  }

  MaintenanceRecord? getLastRecord(String carId, String typeKey) {
    final list = getRecords(carId, typeKey);
    return list.isEmpty ? null : list.first;
  }

  List<MaintenanceRecord> getRecords(String carId, String typeKey) {
    final list = state.records
        .where((r) => r.carId == carId && _sameLogicalType(r.typeKey, typeKey))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  DateTime _addMonths(DateTime d, int months) {
    return DateTime(d.year, d.month + months, d.day, d.hour, d.minute, d.second);
  }

  MaintenanceDueSnapshot computeDue(String carId, String typeKey, int currentMileage) {
    final config = getConfig(carId, typeKey);
    if (config == null) {
      return MaintenanceDueSnapshot.empty();
    }
    if (!config.remindEnabled) {
      return MaintenanceDueSnapshot(hasConfig: true, remindEnabled: false, lastRecord: getLastRecord(carId, typeKey));
    }
    final last = getLastRecord(carId, typeKey);
    if (last == null) {
      return MaintenanceDueSnapshot(hasConfig: true, remindEnabled: true, progress01: 0);
    }

    double? pKm;
    int? nextKm;
    int? kmLeft;
    var overdueKm = false;
    if (config.useKmInterval && config.intervalKm > 0) {
      nextKm = last.odometerKm + config.intervalKm;
      final span = config.intervalKm.toDouble();
      final used = (currentMileage - last.odometerKm).toDouble().clamp(0.0, span * 1.5);
      pKm = (used / span).clamp(0.0, 1.0);
      kmLeft = nextKm - currentMileage;
      overdueKm = currentMileage >= nextKm;
    }

    double? pDate;
    DateTime? nextDate;
    int? daysLeft;
    var overdueDate = false;
    final now = DateTime.now();
    if (config.useMonthsInterval && config.intervalMonths > 0) {
      nextDate = _addMonths(last.date, config.intervalMonths);
      final start = last.date;
      final totalDays = math.max(1, nextDate.difference(start).inDays);
      final elapsed = math.max(0, now.difference(start).inDays);
      pDate = (elapsed / totalDays).clamp(0.0, 1.0);
      final dueDay = DateTime(nextDate.year, nextDate.month, nextDate.day);
      final today = DateTime(now.year, now.month, now.day);
      daysLeft = dueDay.difference(today).inDays;
      overdueDate = !today.isBefore(dueDay);
    }

    double progress;
    if (pKm != null && pDate != null) {
      progress = math.max(pKm, pDate).clamp(0.0, 1.0);
    } else if (pKm != null) {
      progress = pKm;
    } else if (pDate != null) {
      progress = pDate;
    } else {
      progress = 0;
    }

    final overdue = overdueKm || overdueDate;
    if (overdue) progress = 1.0;

    return MaintenanceDueSnapshot(
      hasConfig: true,
      remindEnabled: true,
      lastRecord: last,
      nextDueKm: nextKm,
      nextDueDate: nextDate,
      kmRemaining: kmLeft,
      daysRemaining: daysLeft,
      progress01: progress,
      overdue: overdue,
      overdueByKm: overdueKm,
      overdueByDate: overdueDate,
    );
  }

  /// Только завершённые заказы, у которых `organization_business_kind` входит в [OrgBusinessKind.codesForGarageMaintenanceFromOrders].
  void syncFromOrders(List<Order> orders, List<Car> cars) {
    final doneOrders = orders
        .where((o) => o.status == OrderStatus.done && o.isEligibleForMaintenanceSync)
        .toList();
    final toSync = doneOrders.where((o) => !state.syncedOrderIds.contains(o.id)).toList();
    if (toSync.isEmpty) return;
    final carById = {for (final c in cars) c.id: c};
    final newRecords = <MaintenanceRecord>[];
    final synced = state.syncedOrderIds.toSet();
    for (final order in toSync) {
      final car = carById[order.carId];
      final odometer = order.odometerAtCompletion ?? car?.mileage ?? 0;
      final place = order.stoName;
      var itemIndex = 0;
      for (final item in order.items) {
        if (item.isCompleted != true) {
          itemIndex++;
          continue;
        }
        final type = MaintenanceType.fromServiceName(item.name);
        if (type == null) {
          itemIndex++;
          continue;
        }
        final recordId = 'ord_${order.id}_${type.name}_$itemIndex';
        if (state.records.any((r) => r.id == recordId)) {
          itemIndex++;
          continue;
        }
        newRecords.add(MaintenanceRecord(
          id: recordId,
          carId: order.carId,
          typeKey: type.name,
          odometerKm: odometer,
          date: order.dateTime,
          place: place.isNotEmpty ? place : null,
          orderId: order.id,
        ));
        itemIndex++;
      }
      synced.add(order.id);
    }
    var newRecordsM = _migrateRecords([...state.records, ...newRecords]);
    if (newRecords.isEmpty) {
      state = MaintenanceRemindersState(configs: state.configs, records: newRecordsM, syncedOrderIds: synced);
    } else {
      state = MaintenanceRemindersState(
        configs: state.configs,
        records: newRecordsM,
        syncedOrderIds: synced,
      );
    }
    _save();
  }

  void setConfig(MaintenanceConfig config) {
    final tk = config.typeKey == 'oilFilter' ? MaintenanceType.oil.name : config.typeKey;
    final c = MaintenanceConfig(
      carId: config.carId,
      typeKey: tk,
      intervalKm: config.intervalKm,
      useKmInterval: config.useKmInterval,
      intervalMonths: config.intervalMonths,
      useMonthsInterval: config.useMonthsInterval,
      remindEnabled: config.remindEnabled,
    );
    final newConfigs = state.configs.where((x) => !(x.carId == c.carId && _sameLogicalType(x.typeKey, c.typeKey))).toList();
    newConfigs.add(c);
    state = MaintenanceRemindersState(configs: newConfigs, records: state.records, syncedOrderIds: state.syncedOrderIds);
    _save();
  }

  void deleteConfig(String carId, String typeKey) {
    final newConfigs =
        state.configs.where((c) => !(c.carId == carId && _sameLogicalType(c.typeKey, typeKey))).toList();
    state = MaintenanceRemindersState(configs: newConfigs, records: state.records, syncedOrderIds: state.syncedOrderIds);
    _save();
  }

  /// Удаление авто из гаража: все интервалы ТО и записи по этому [carId].
  void removeAllDataForCar(String carId) {
    if (carId.isEmpty) return;
    final newConfigs = state.configs.where((c) => c.carId != carId).toList();
    final newRecords = state.records.where((r) => r.carId != carId).toList();
    state = MaintenanceRemindersState(
      configs: newConfigs,
      records: newRecords,
      syncedOrderIds: state.syncedOrderIds,
    );
    _save();
  }

  void addRecord(MaintenanceRecord record) {
    final tk = record.typeKey == 'oilFilter' ? MaintenanceType.oil.name : record.typeKey;
    final r = MaintenanceRecord(
      id: record.id,
      carId: record.carId,
      typeKey: tk,
      odometerKm: record.odometerKm,
      date: record.date,
      place: record.place,
      orderId: record.orderId,
    );
    state = MaintenanceRemindersState(
      configs: state.configs,
      records: [...state.records, r],
      syncedOrderIds: state.syncedOrderIds,
    );
    _save();
  }

  void removeRecord(String id) {
    state = MaintenanceRemindersState(
      configs: state.configs,
      records: state.records.where((r) => r.id != id).toList(),
      syncedOrderIds: state.syncedOrderIds,
    );
    _save();
  }

  void setRemindEnabled(String carId, String typeKey, bool enabled) {
    final c = getConfig(carId, typeKey);
    if (c != null) {
      setConfig(MaintenanceConfig(
        carId: c.carId,
        typeKey: c.typeKey,
        intervalKm: c.intervalKm,
        useKmInterval: c.useKmInterval,
        intervalMonths: c.intervalMonths,
        useMonthsInterval: c.useMonthsInterval,
        remindEnabled: enabled,
      ));
    }
  }

  /// Активные напоминания по умолчанию (только если для типа ещё нет конфигурации).
  void ensureStandardRemindersForCar(String carId) {
    if (carId.isEmpty) return;
    var configs = [...state.configs];
    var changed = false;
    void addKm(MaintenanceType type, int intervalKm) {
      if (configs.any((c) => c.carId == carId && _sameLogicalType(c.typeKey, type.name))) {
        return;
      }
      configs.add(MaintenanceConfig(
        carId: carId,
        typeKey: type.name,
        intervalKm: intervalKm,
        useKmInterval: true,
        intervalMonths: 0,
        useMonthsInterval: false,
        remindEnabled: true,
      ));
      changed = true;
    }

    addKm(MaintenanceType.oil, 7000);
    addKm(MaintenanceType.airFilter, 14000);
    addKm(MaintenanceType.brakes, 30000);
    addKm(MaintenanceType.alignment, 30000);
    if (!changed) return;
    state = MaintenanceRemindersState(
      configs: configs,
      records: state.records,
      syncedOrderIds: state.syncedOrderIds,
    );
    _save();
  }
}
