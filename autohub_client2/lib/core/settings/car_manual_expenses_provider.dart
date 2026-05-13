import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_exceptions.dart';
import '../auth/auth_provider.dart'
    show apiClientProvider, authProvider, sharedPreferencesProvider;
import '../auth/device_id_service.dart';
import 'car_manual_expense_models.dart';
import 'car_manual_expenses_sync_service.dart';

export 'car_manual_expense_models.dart';

const _kCarManualExpensesPrefix = 'car_manual_expenses_';
const _kMigratedV1Prefix = 'manual_expenses_sync_migrated_v1_';

String _lastPullKey(String userId, String carId) =>
    'manual_expenses_last_pull_${userId}_$carId';

List<CarManualExpenseRecord> _loadPrefsState(
  SharedPreferences? prefs,
  String? userId,
) {
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

List<CarManualExpenseRecord> _mergeCarServerItems({
  required List<CarManualExpenseRecord> fullLocal,
  required String carId,
  required List<Map<String, dynamic>> serverItems,
}) {
  final otherCars = fullLocal.where((e) => e.carId != carId).toList();
  final forCar = fullLocal.where((e) => e.carId == carId).toList();
  final byKey = <String, CarManualExpenseRecord>{
    for (final l in forCar) l.effectiveClientRecordId: l,
  };
  for (final raw in serverItems) {
    final p = CarManualExpenseRecord.fromServerItemMap(
      raw,
      fallbackCarId: carId,
    );
    if (p == null || p.carId != carId) continue;
    final k = p.effectiveClientRecordId;
    byKey[k] = p;
  }
  return [...otherCars, ...byKey.values];
}

final carManualExpensesSyncServiceProvider =
    Provider<CarManualExpensesSyncService>(
      (ref) => CarManualExpensesSyncService(ref.watch(apiClientProvider)),
    );

final carManualExpensesProvider =
    StateNotifierProvider<
      CarManualExpensesNotifier,
      List<CarManualExpenseRecord>
    >((ref) {
      ref.watch(sharedPreferencesProvider);
      ref.watch(authProvider);
      return CarManualExpensesNotifier(ref);
    });

class CarManualExpensesNotifier
    extends StateNotifier<List<CarManualExpenseRecord>> {
  CarManualExpensesNotifier(this._ref)
    : super(
        _loadPrefsState(
          _ref.read(sharedPreferencesProvider).valueOrNull,
          _ref.read(authProvider).user?.id,
        ),
      ) {
    Future.microtask(() async {
      await _applyMigratedV1IfNeeded();
      await syncAllUserCars();
    });
  }

  final Ref _ref;

  SharedPreferences? get _prefs =>
      _ref.read(sharedPreferencesProvider).valueOrNull;
  String? get _userId => _ref.read(authProvider).user?.id;

  String get _storageKey => _kCarManualExpensesPrefix + (_userId ?? '');

  final Map<String, DateTime> _lastSyncByCar = {};

  void _reloadFromPrefs() {
    final p = _prefs;
    final uid = _userId;
    state = _loadPrefsState(p, uid);
  }

  Future<void> _applyMigratedV1IfNeeded() async {
    final p = _prefs;
    final uid = _userId;
    if (p == null || uid == null) return;
    final flagKey = _kMigratedV1Prefix + uid;
    if (p.getBool(flagKey) == true) return;
    final next = <CarManualExpenseRecord>[
      for (final r in state)
        if (r.syncStatus == null && (r.serverId == null || r.serverId!.isEmpty))
          r.copyWith(
            clientRecordId: r.clientRecordId ?? r.id,
            syncStatus: CarManualExpenseSyncStatus.pendingCreate,
            localUpdatedAt: r.localUpdatedAt ?? r.date,
            lastSyncError: null,
          )
        else
          r,
    ];
    state = next;
    await _save();
    await p.setBool(flagKey, true);
  }

  CarManualExpenseRecord? _findByStableId(String id) {
    for (final e in state) {
      if (e.id == id) return e;
      if (e.effectiveClientRecordId == id) return e;
    }
    return null;
  }

  bool _sameManualRecord(CarManualExpenseRecord a, CarManualExpenseRecord b) {
    if (a.id == b.id) return true;
    return a.carId == b.carId &&
        a.effectiveClientRecordId == b.effectiveClientRecordId;
  }

  Future<void> _save() async {
    final p = _prefs;
    final uid = _userId;
    if (p == null || uid == null) return;
    await p.setString(
      _storageKey,
      jsonEncode(state.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> loadFromPrefs() async {
    _reloadFromPrefs();
  }

  void add(CarManualExpenseRecord r) {
    final now = DateTime.now();
    final withMeta = r.copyWith(
      syncStatus: CarManualExpenseSyncStatus.pendingCreate,
      localUpdatedAt: now,
      lastSyncError: null,
    );
    state = [...state, withMeta];
    unawaited(_save());
    _scheduleSync();
  }

  void update(CarManualExpenseRecord r) {
    final prev = _findByStableId(r.id);
    final now = DateTime.now();
    final CarManualExpenseSyncStatus nextStatus;
    if (prev?.syncStatus == CarManualExpenseSyncStatus.pendingCreate) {
      nextStatus = CarManualExpenseSyncStatus.pendingCreate;
    } else if (prev?.serverId == null || prev!.serverId!.isEmpty) {
      nextStatus = CarManualExpenseSyncStatus.pendingCreate;
    } else {
      nextStatus = CarManualExpenseSyncStatus.pendingUpdate;
    }
    final merged = r.copyWith(
      syncStatus: nextStatus,
      localUpdatedAt: now,
      lastSyncError: null,
    );
    state = [
      for (final e in state)
        if (_sameManualRecord(e, r)) merged else e,
    ];
    unawaited(_save());
    _scheduleSync();
  }

  void deleteRecord(String id) {
    final prev = _findByStableId(id);
    if (prev == null) return;
    final hasNeverSynced = prev.serverId == null || prev.serverId!.isEmpty;
    final isLocalOnly =
        hasNeverSynced &&
        (prev.syncStatus == CarManualExpenseSyncStatus.pendingCreate ||
            prev.syncStatus == CarManualExpenseSyncStatus.failed);
    if (isLocalOnly) {
      state = state.where((e) => e.id != prev.id).toList();
    } else {
      final now = DateTime.now();
      state = [
        for (final e in state)
          if (e.id == prev.id)
            e.copyWith(
              syncStatus: CarManualExpenseSyncStatus.pendingDelete,
              deletedAt: now,
              localUpdatedAt: now,
              lastSyncError: null,
            )
          else
            e,
      ];
    }
    unawaited(_save());
    _scheduleSync();
  }

  void remove(String id) => deleteRecord(id);

  void removeAllDataForCar(String carId) {
    if (carId.isEmpty) return;
    state = state.where((e) => e.carId != carId).toList();
    unawaited(_save());
  }

  void _scheduleSync() {
    unawaited(
      Future(() async {
        try {
          await syncAllUserCars();
        } catch (_) {}
      }),
    );
  }

  DateTime? _readLastPull(String carId) {
    final p = _prefs;
    final uid = _userId;
    if (p == null || uid == null) return null;
    final raw = p.getString(_lastPullKey(uid, carId));
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> _writeLastPull(String carId, DateTime t) async {
    final p = _prefs;
    final uid = _userId;
    if (p == null || uid == null) return;
    await p.setString(_lastPullKey(uid, carId), t.toUtc().toIso8601String());
  }

  Future<void> syncForCar(String carId, {bool bypassThrottle = false}) async {
    final uid = _userId;
    if (uid == null || uid.isEmpty || carId.isEmpty) return;
    if (!_ref.read(authProvider).isAuthenticated) return;
    final tick = DateTime.now();
    if (!bypassThrottle) {
      final prev = _lastSyncByCar[carId];
      if (prev != null &&
          tick.difference(prev) < const Duration(milliseconds: 800)) {
        return;
      }
    }
    _lastSyncByCar[carId] = tick;
    try {
      final svc = _ref.read(carManualExpensesSyncServiceProvider);
      final p = _prefs;
      final deviceId = p != null ? await getOrCreateDeviceId(p) : null;
      final last = _readLastPull(carId);
      final res = await svc.syncCar(
        carId: carId,
        localRecords: state.where((e) => e.carId == carId).toList(),
        lastPulledAt: last,
        deviceId: deviceId,
      );
      state = _mergeCarServerItems(
        fullLocal: state,
        carId: carId,
        serverItems: res.items,
      );
      await _writeLastPull(carId, res.serverTime ?? DateTime.now());
      await _save();
    } on ApiException catch (e) {
      _markCarFailed(carId, e.message);
    } catch (_) {
      _markCarFailed(carId, 'network');
    }
  }

  void _markCarFailed(String carId, String message) {
    state = [
      for (final e in state)
        if (e.carId == carId &&
            e.isDirtyForSync &&
            e.syncStatus != CarManualExpenseSyncStatus.pendingDelete)
          e.copyWith(
            syncStatus: CarManualExpenseSyncStatus.failed,
            lastSyncError: message,
          )
        else
          e,
    ];
    unawaited(_save());
  }

  Future<void> syncAllUserCars() async {
    final uid = _userId;
    if (uid == null || uid.isEmpty) return;
    if (!_ref.read(authProvider).isAuthenticated) return;
    final ids = <String>{for (final r in state) r.carId};
    for (final id in ids) {
      await syncForCar(id);
    }
  }

  /// Синхронизация по всем авто из гаража (в т.ч. без локальных расходов) + уже известные записи.
  Future<void> syncGarageAndManual(List<String> garageCarIds) async {
    final uid = _userId;
    if (uid == null || uid.isEmpty) return;
    if (!_ref.read(authProvider).isAuthenticated) return;
    final ids = <String>{
      ...garageCarIds.where((id) => id.isNotEmpty),
      for (final r in state) r.carId,
    };
    for (final id in ids) {
      await syncForCar(id, bypassThrottle: true);
    }
  }
}
