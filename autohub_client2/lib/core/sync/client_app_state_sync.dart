import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_endpoints.dart';
import '../auth/auth_provider.dart';
import '../providers/app_providers.dart' show profileNotesProvider;
import '../settings/favorite_sto_ids_provider.dart';
import '../settings/maintenance_reminders_provider.dart';
import '../settings/theme_mode_provider.dart';
import 'client_app_state_schema.dart';

final clientAppStateSyncServiceProvider = Provider<ClientAppStateSyncService>((ref) {
  return ClientAppStateSyncService(ref);
});

/// Синхронизация снимка настроек клиента с `GET/PUT /profile/client-app-state`.
class ClientAppStateSyncService {
  ClientAppStateSyncService(this._ref);

  final Ref _ref;
  DateTime? _lastResumePull;
  static const _resumeMinGap = Duration(minutes: 2);

  Future<void> pullAfterLogin() => _pull(applyLocal: true);

  Future<void> maybePullOnAppResume() async {
    final now = DateTime.now();
    if (_lastResumePull != null && now.difference(_lastResumePull!) < _resumeMinGap) return;
    await _pull(applyLocal: true);
  }

  Future<void> pushLocalToServer() async {
    final uid = _ref.read(authProvider).user?.id;
    if (uid == null || uid.isEmpty) return;
    final client = _ref.read(apiClientProvider);
    if (client.accessToken == null || client.accessToken!.isEmpty) return;

    final prefs = await _ref.read(sharedPreferencesProvider.future);

    Map<String, dynamic> existing = {};
    try {
      final res = await client.get<Map<String, dynamic>>(ApiEndpoints.profileClientAppState);
      final raw = res.data?['payload'];
      if (raw is Map) {
        existing = Map<String, dynamic>.from(raw);
      }
    } catch (_) {}

    final merged = Map<String, dynamic>.from(existing);
    final tm = prefs.getString(kClientThemeModeKey);
    if (tm != null && tm.isNotEmpty) {
      merged[ClientAppStateSchema.serverKeyThemeMode] = tm;
    }
    final notesKey = ClientAppStateSchema.profileNotesPrefix + uid;
    final notesRaw = prefs.getString(notesKey);
    if (notesRaw != null && notesRaw.isNotEmpty) {
      merged[ClientAppStateSchema.serverKeyProfileNotes] = notesRaw;
    }

    final maintCfg = prefs.getString(ClientAppStateSchema.prefsMaintenanceConfigKey(uid));
    if (maintCfg != null && maintCfg.isNotEmpty) {
      merged[ClientAppStateSchema.serverKeyMaintenanceConfigsJson] = maintCfg;
    }
    final maintRec = prefs.getString(ClientAppStateSchema.prefsMaintenanceRecordsKey(uid));
    if (maintRec != null && maintRec.isNotEmpty) {
      merged[ClientAppStateSchema.serverKeyMaintenanceRecordsJson] = maintRec;
    }
    final maintSync = prefs.getString(ClientAppStateSchema.prefsMaintenanceSyncedOrderIdsKey(uid));
    if (maintSync != null && maintSync.isNotEmpty) {
      merged[ClientAppStateSchema.serverKeyMaintenanceSyncedOrderIdsJson] = maintSync;
    }

    final favG = prefs.getStringList('favorite_sto_ids_$uid') ?? <String>[];
    merged[ClientAppStateSchema.serverKeyFavoriteStoGlobalJson] = jsonEncode(favG);
    final favPc = prefs.getString('per_car_favorite_sto_ids_$uid');
    if (favPc != null && favPc.isNotEmpty) {
      merged[ClientAppStateSchema.serverKeyFavoriteStoPerCarJson] = favPc;
    } else {
      merged[ClientAppStateSchema.serverKeyFavoriteStoPerCarJson] = '{}';
    }

    try {
      await client.put<Map<String, dynamic>>(
        ApiEndpoints.profileClientAppState,
        data: {'payload': merged},
      );
    } catch (_) {}
  }

  Future<void> _pull({required bool applyLocal}) async {
    final uid = _ref.read(authProvider).user?.id;
    if (uid == null || uid.isEmpty) return;
    final client = _ref.read(apiClientProvider);
    if (client.accessToken == null || client.accessToken!.isEmpty) return;

    try {
      final res = await client.get<Map<String, dynamic>>(ApiEndpoints.profileClientAppState);
      _lastResumePull = DateTime.now();
      final payload = res.data?['payload'];
      if (payload is! Map) return;
      final m = Map<String, dynamic>.from(payload);
      if (!applyLocal) return;

      final prefs = await _ref.read(sharedPreferencesProvider.future);
      final tm = m[ClientAppStateSchema.serverKeyThemeMode];
      if (tm is String && tm.isNotEmpty) {
        await prefs.setString(kClientThemeModeKey, tm);
        _ref.invalidate(themeModeProvider);
      }
      final notes = m[ClientAppStateSchema.serverKeyProfileNotes];
      if (notes is String && notes.isNotEmpty) {
        try {
          jsonDecode(notes);
          await prefs.setString(ClientAppStateSchema.profileNotesPrefix + uid, notes);
          _ref.invalidate(profileNotesProvider);
        } catch (_) {
          /* битые заметки не блокируют остальной pull */
        }
      }

      Future<bool> pullMaintenanceSlice(String serverKey, String Function(String uid) prefsKey) async {
        final v = m[serverKey];
        if (v is! String || v.isEmpty) return false;
        try {
          jsonDecode(v);
        } catch (_) {
          return false;
        }
        await prefs.setString(prefsKey(uid), v);
        return true;
      }

      var maintTouched = false;
      if (await pullMaintenanceSlice(
            ClientAppStateSchema.serverKeyMaintenanceConfigsJson,
            ClientAppStateSchema.prefsMaintenanceConfigKey,
          )) {
        maintTouched = true;
      }
      if (await pullMaintenanceSlice(
            ClientAppStateSchema.serverKeyMaintenanceRecordsJson,
            ClientAppStateSchema.prefsMaintenanceRecordsKey,
          )) {
        maintTouched = true;
      }
      if (await pullMaintenanceSlice(
            ClientAppStateSchema.serverKeyMaintenanceSyncedOrderIdsJson,
            ClientAppStateSchema.prefsMaintenanceSyncedOrderIdsKey,
          )) {
        maintTouched = true;
      }
      if (maintTouched) {
        _ref.invalidate(maintenanceRemindersProvider);
      }

      var favTouched = false;
      final fJson = m[ClientAppStateSchema.serverKeyFavoriteStoGlobalJson];
      if (fJson is String && fJson.isNotEmpty) {
        try {
          final list = jsonDecode(fJson);
          if (list is List) {
            await prefs.setStringList(
              'favorite_sto_ids_$uid',
              list.map((e) => e.toString()).toList(),
            );
            favTouched = true;
          }
        } catch (_) {}
      }
      final pcJson = m[ClientAppStateSchema.serverKeyFavoriteStoPerCarJson];
      if (pcJson is String && pcJson.isNotEmpty) {
        try {
          final dec = jsonDecode(pcJson);
          if (dec is Map) {
            await prefs.setString('per_car_favorite_sto_ids_$uid', pcJson);
            favTouched = true;
          }
        } catch (_) {}
      }
      if (favTouched) {
        _ref.invalidate(favoriteStoStateProvider);
      }
    } catch (_) {}
  }
}
