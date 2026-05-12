import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_provider.dart' show authProvider, sharedPreferencesProvider;

const _kCompletedPrefix = 'garage_first_car_tutorial_completed_v1_';

/// Шаги сценария после добавления первой машины (подсветка + нижняя панель).
enum GarageFirstCarTutorialStep {
  /// Не показываем сценарий.
  inactive,

  /// Гараж: блок «Напоминания о ТО».
  garageReminders,

  /// Экран напоминаний: типы работ и интервалы.
  maintenanceIntro,

  /// Экран напоминаний: история / «зафиксировать работу».
  maintenanceHistory,

  /// Подсказка про документы в карточке авто.
  documentsInfo,

  /// Вкладка «Мои сервисы» (избранное).
  servicesFavorites,

  /// Вкладка «Поиск»: карта и список, фильтры.
  searchMapAndFilters,

  /// Запись в СТО, цены, карточка точки.
  bookingHint,
}

class GarageFirstCarTutorialState {
  const GarageFirstCarTutorialState({
    required this.active,
    required this.step,
    this.carId,
  });

  final bool active;
  final GarageFirstCarTutorialStep step;
  final String? carId;

  static const inactive = GarageFirstCarTutorialState(active: false, step: GarageFirstCarTutorialStep.inactive);

  GarageFirstCarTutorialState copyWith({
    bool? active,
    GarageFirstCarTutorialStep? step,
    String? carId,
  }) {
    return GarageFirstCarTutorialState(
      active: active ?? this.active,
      step: step ?? this.step,
      carId: carId ?? this.carId,
    );
  }
}

final garageFirstCarTutorialProvider =
    StateNotifierProvider<GarageFirstCarTutorialNotifier, GarageFirstCarTutorialState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  final userId = ref.watch(authProvider).user?.id;
  return GarageFirstCarTutorialNotifier(prefs, userId);
});

class GarageFirstCarTutorialNotifier extends StateNotifier<GarageFirstCarTutorialState> {
  GarageFirstCarTutorialNotifier(this._prefs, this._userId) : super(GarageFirstCarTutorialState.inactive);

  final SharedPreferences? _prefs;
  final String? _userId;

  bool _isPersistedCompleted() {
    final p = _prefs;
    final u = _userId;
    if (p == null || u == null || u.isEmpty) return false;
    return p.getBool(_kCompletedPrefix + u) == true;
  }

  Future<void> _persistCompleted() async {
    final p = _prefs;
    final u = _userId;
    if (p == null || u == null || u.isEmpty) return;
    await p.setBool(_kCompletedPrefix + u, true);
  }

  /// Запуск только для первой добавленной машины (вызывать из гаража, если до добавления список был пуст).
  void tryStart(String carId) {
    if (carId.isEmpty) return;
    if (_isPersistedCompleted()) return;
    if (state.active) return;
    state = GarageFirstCarTutorialState(
      active: true,
      step: GarageFirstCarTutorialStep.garageReminders,
      carId: carId,
    );
  }

  Future<void> skip() async {
    await _persistCompleted();
    state = GarageFirstCarTutorialState.inactive;
  }

  Future<void> completeFlow() async {
    await _persistCompleted();
    state = GarageFirstCarTutorialState.inactive;
  }

  void setStep(GarageFirstCarTutorialStep step) {
    if (!state.active) return;
    state = state.copyWith(step: step);
  }
}
