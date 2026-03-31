import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_provider.dart' show authProvider, sharedPreferencesProvider;

const _kSeenCars = 'garage_maintenance_onboarding_seen_';

/// ID машин, для которых уже показывали (или пользователь закрыл) баннер «настроить ТО».
final garageMaintenanceOnboardingSeenProvider =
    StateNotifierProvider<GarageMaintenanceOnboardingNotifier, Set<String>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  final userId = ref.watch(authProvider).user?.id;
  return GarageMaintenanceOnboardingNotifier(prefs, userId);
});

class GarageMaintenanceOnboardingNotifier extends StateNotifier<Set<String>> {
  GarageMaintenanceOnboardingNotifier(this._prefs, this._userId) : super(_load(_prefs, _userId));

  final SharedPreferences? _prefs;
  final String? _userId;

  static Set<String> _load(SharedPreferences? prefs, String? userId) {
    if (prefs == null || userId == null) return {};
    try {
      final raw = prefs.getString(_kSeenCars + userId);
      if (raw == null || raw.isEmpty) return {};
      final list = jsonDecode(raw) as List<dynamic>?;
      return list?.map((e) => e as String).toSet() ?? {};
    } catch (_) {
      return {};
    }
  }

  bool hasSeen(String carId) => state.contains(carId);

  Future<void> markSeen(String carId) async {
    if (carId.isEmpty) return;
    if (state.contains(carId)) return;
    final next = Set<String>.from(state)..add(carId);
    state = next;
    final p = _prefs;
    final u = _userId;
    if (p != null && u != null) {
      await p.setString(_kSeenCars + u, jsonEncode(next.toList()));
    }
  }
}
