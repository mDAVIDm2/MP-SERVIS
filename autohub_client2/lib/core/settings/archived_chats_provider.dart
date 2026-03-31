import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_provider.dart';

const _kArchivedChatIdsPrefix = 'archived_chat_ids_';

/// Локально сохранённый список id чатов, перенесённых в архив (свайп вправо).
final archivedChatIdsProvider =
    StateNotifierProvider<ArchivedChatIdsNotifier, Set<String>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  final userId = ref.watch(authProvider).user?.id ?? '';
  return ArchivedChatIdsNotifier(prefs, userId);
});

class ArchivedChatIdsNotifier extends StateNotifier<Set<String>> {
  ArchivedChatIdsNotifier(SharedPreferences? prefs, this._userId)
      : _prefs = prefs,
        super(_load(prefs, _userId));

  final SharedPreferences? _prefs;
  final String _userId;

  static Set<String> _load(SharedPreferences? prefs, String userId) {
    if (prefs == null || userId.isEmpty) return {};
    final raw = prefs.getString(_kArchivedChatIdsPrefix + userId);
    if (raw == null) return {};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  void _save() {
    if (_prefs == null || _userId.isEmpty) return;
    _prefs.setString(_kArchivedChatIdsPrefix + _userId, jsonEncode(state.toList()));
  }

  void archive(String chatId) {
    state = {...state, chatId};
    _save();
  }

  void unarchive(String chatId) {
    state = {...state}..remove(chatId);
    _save();
  }

  void toggle(String chatId) {
    if (state.contains(chatId)) {
      unarchive(chatId);
    } else {
      archive(chatId);
    }
  }
}
