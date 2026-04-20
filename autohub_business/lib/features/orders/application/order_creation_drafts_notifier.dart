import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_provider.dart';
import '../domain/order_creation_draft.dart';

/// Локальные черновики создания заказа (по организации), максимум [maxDrafts].
class OrderCreationDraftsNotifier extends StateNotifier<List<OrderCreationDraft>> {
  OrderCreationDraftsNotifier(this._ref) : super([]) {
    _ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev?.user?.organizationId != next.user?.organizationId) {
        Future.microtask(_reload);
      }
    });
    Future.microtask(_reload);
  }

  final Ref _ref;

  static const maxDrafts = 10;

  static String _storageKey(String? orgId) => 'order_creation_drafts_v1_${orgId ?? 'none'}';

  Future<void> _reload() async {
    final orgId = _ref.read(authProvider).user?.organizationId;
    if (orgId == null || orgId.isEmpty) {
      state = [];
      return;
    }
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    final raw = prefs.getString(_storageKey(orgId));
    if (raw == null || raw.isEmpty) {
      state = [];
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        state = [];
        return;
      }
      var list = decoded
          .map((e) => OrderCreationDraft.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (list.length > maxDrafts) {
        list = list.sublist(0, maxDrafts);
      }
      state = list;
    } catch (_) {
      state = [];
    }
  }

  Future<void> _persist() async {
    final orgId = _ref.read(authProvider).user?.organizationId;
    if (orgId == null || orgId.isEmpty) return;
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    await prefs.setString(_storageKey(orgId), jsonEncode(state.map((e) => e.toJson()).toList()));
  }

  /// Сохранить или обновить черновик. При превышении лимита удаляются самые старые.
  Future<void> upsertFromSnapshot({
    String? existingId,
    required String source,
    required Map<String, dynamic> data,
  }) async {
    final orgId = _ref.read(authProvider).user?.organizationId;
    if (orgId == null || orgId.isEmpty) return;

    final id = existingId ??
        'draft_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
    final draft = OrderCreationDraft(
      id: id,
      source: source,
      updatedAt: DateTime.now(),
      data: data,
    );
    var list = [...state];
    final idx = list.indexWhere((e) => e.id == id);
    if (idx >= 0) {
      list[idx] = draft;
    } else {
      list.add(draft);
    }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (list.length > maxDrafts) {
      list = list.sublist(0, maxDrafts);
    }
    state = list;
    await _persist();
  }

  Future<void> remove(String id) async {
    state = state.where((e) => e.id != id).toList();
    await _persist();
  }
}

final orderCreationDraftsProvider =
    StateNotifierProvider<OrderCreationDraftsNotifier, List<OrderCreationDraft>>((ref) {
  return OrderCreationDraftsNotifier(ref);
});
