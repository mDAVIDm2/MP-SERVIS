import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/api_exceptions.dart';
import 'car_manual_expense_models.dart';

/// Результат POST sync.
class ManualExpensesSyncResult {
  ManualExpensesSyncResult({
    required this.serverTime,
    required this.items,
    this.nextCursor,
  });

  final DateTime? serverTime;
  final List<Map<String, dynamic>> items;
  final String? nextCursor;
}

/// REST-слой синхронизации ручных расходов (без UI).
class CarManualExpensesSyncService {
  CarManualExpensesSyncService(this._client);

  final ApiClient _client;

  String _basePath(String carId) =>
      '${ApiEndpoints.profileCar(carId)}/manual-expenses';

  Future<List<Map<String, dynamic>>> pullRemote({
    required String carId,
    DateTime? since,
    bool includeDeleted = true,
    int limit = 500,
  }) async {
    final q = <String, dynamic>{
      'includeDeleted': includeDeleted ? 'true' : 'false',
      'limit': limit,
    };
    if (since != null) {
      q['updatedSince'] = since.toUtc().toIso8601String();
    }
    final res = await _client.get<Map<String, dynamic>>(
      _basePath(carId),
      queryParameters: q,
    );
    final data = res.data;
    if (data == null) {
      throw const ApiException(
        code: ApiErrorCode.internal,
        message: 'Пустой ответ',
      );
    }
    final items = data['items'];
    if (items is! List) return [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> upsertRemote({
    required String carId,
    required CarManualExpenseRecord record,
    String? deviceId,
  }) async {
    final cid = Uri.encodeComponent(record.effectiveClientRecordId);
    final body = record.toUpsertRequestBody(deviceId: deviceId);
    final res = await _client.put<Map<String, dynamic>>(
      '${_basePath(carId)}/$cid',
      data: body,
    );
    final data = res.data;
    if (data == null) {
      throw const ApiException(
        code: ApiErrorCode.internal,
        message: 'Пустой ответ',
      );
    }
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>?> deleteRemote({
    required String carId,
    required String clientRecordId,
  }) async {
    final cid = Uri.encodeComponent(clientRecordId);
    try {
      final res = await _client.delete<Map<String, dynamic>>(
        '${_basePath(carId)}/$cid',
      );
      return res.data != null ? Map<String, dynamic>.from(res.data!) : null;
    } on DioException catch (e) {
      final err = e.error;
      if (err is ApiException && err.code == ApiErrorCode.notFound) {
        return null;
      }
      rethrow;
    }
  }

  Future<ManualExpensesSyncResult> syncCar({
    required String carId,
    required List<CarManualExpenseRecord> localRecords,
    required DateTime? lastPulledAt,
    String? deviceId,
  }) async {
    final upserts = <Map<String, dynamic>>[];
    final deletes = <Map<String, dynamic>>[];
    for (final r in localRecords) {
      if (r.syncStatus == CarManualExpenseSyncStatus.pendingDelete) {
        deletes.add({
          'clientRecordId': r.effectiveClientRecordId,
          if (r.localUpdatedAt != null)
            'clientUpdatedAt': r.localUpdatedAt!.toUtc().toIso8601String(),
        });
        continue;
      }
      final needsPush =
          r.syncStatus == CarManualExpenseSyncStatus.pendingCreate ||
          r.syncStatus == CarManualExpenseSyncStatus.pendingUpdate ||
          r.syncStatus == CarManualExpenseSyncStatus.failed ||
          (r.syncStatus == null && (r.serverId == null || r.serverId!.isEmpty));
      if (needsPush) {
        upserts.add({
          'clientRecordId': r.effectiveClientRecordId,
          ...r.toUpsertRequestBody(deviceId: deviceId),
        });
      }
    }
    final body = <String, dynamic>{
      if (lastPulledAt != null)
        'lastPulledAt': lastPulledAt.toUtc().toIso8601String(),
      'changes': {'upserts': upserts, 'deletes': deletes},
    };
    final res = await _client.post<Map<String, dynamic>>(
      '${_basePath(carId)}/sync',
      data: body,
    );
    final data = res.data;
    if (data == null) {
      throw const ApiException(
        code: ApiErrorCode.internal,
        message: 'Пустой ответ',
      );
    }
    final itemsRaw = data['items'];
    final items = itemsRaw is List
        ? itemsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
    DateTime? st;
    final stRaw = data['serverTime'] as String?;
    if (stRaw != null) {
      st = DateTime.tryParse(stRaw);
    }
    final next = data['nextCursor'] as String?;
    return ManualExpensesSyncResult(
      serverTime: st,
      items: items,
      nextCursor: next,
    );
  }
}
