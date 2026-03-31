import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_provider.dart';
import 'organization_repository.dart';

const _kPrefix = 'client_note_';

String clientNoteKey(String name, String? phone) =>
    '${name}_${phone ?? ''}'.replaceAll(RegExp(r'\s'), '_');

/// Внутренние заметки по клиенту. Ключ в prefs: client_note_<orgId>_<clientKey> — у каждой организации свой набор заметок.
class ClientNotesRepository extends StateNotifier<Map<String, String>> {
  ClientNotesRepository(this._prefs, this._orgId) : super(_loadAll(_prefs, _orgId));

  final SharedPreferences _prefs;
  final String? _orgId;

  static String _prefsKey(String? orgId, String clientKey) {
    if (orgId == null || orgId.isEmpty) return _kPrefix + clientKey;
    return _kPrefix + orgId + '_' + clientKey;
  }

  static Map<String, String> _loadAll(SharedPreferences prefs, String? orgId) {
    final prefix = orgId == null ? _kPrefix : _kPrefix + orgId + '_';
    final keys = prefs.getKeys().where((k) => k.startsWith(prefix));
    final map = <String, String>{};
    for (final k in keys) {
      final key = k.substring(prefix.length);
      final v = prefs.getString(k);
      if (v != null) map[key] = v;
    }
    return map;
  }

  String? getNote(String clientKey) => state[clientKey];

  void setNote(String clientKey, String text) {
    state = {...state, clientKey: text};
    if (_orgId == null) return;
    final fullKey = _prefsKey(_orgId, clientKey);
    if (text.isEmpty) {
      _prefs.remove(fullKey);
    } else {
      _prefs.setString(fullKey, text);
    }
  }
}

final clientNotesRepositoryProvider =
    StateNotifierProvider<ClientNotesRepository, Map<String, String>>((ref) {
  final prefs = ref.watch(sharedPreferencesOrgProvider).valueOrNull;
  final orgId = ref.watch(authProvider).user?.organizationId;
  if (prefs == null) return ClientNotesRepository(_StubPrefs(), orgId);
  return ClientNotesRepository(prefs, orgId);
});

class _StubPrefs implements SharedPreferences {
  @override
  Set<String> getKeys() => {};
  @override
  Object? get(String key) => null;
  @override
  bool? getBool(String key) => null;
  @override
  int? getInt(String key) => null;
  @override
  double? getDouble(String key) => null;
  @override
  String? getString(String key) => null;
  @override
  List<String>? getStringList(String key) => null;
  @override
  Future<bool> setString(String key, String value) async => false;
  @override
  Future<bool> setBool(String key, bool value) async => false;
  @override
  Future<bool> setInt(String key, int value) async => false;
  @override
  Future<bool> setDouble(String key, double value) async => false;
  @override
  Future<bool> setStringList(String key, List<String> value) async => false;
  @override
  Future<bool> remove(String key) async => false;
  @override
  Future<bool> clear() async => false;
  @override
  bool containsKey(String key) => false;
  @override
  Future<bool> commit() async => false;
  @override
  Future<bool> reload() async => false;
}
