import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_endpoints.dart';
import '../auth/auth_provider.dart';
import '../providers/app_providers.dart' show profileNotesProvider;
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
        } catch (_) {
          return;
        }
        await prefs.setString(ClientAppStateSchema.profileNotesPrefix + uid, notes);
        _ref.invalidate(profileNotesProvider);
      }
    } catch (_) {}
  }
}
