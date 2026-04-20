import 'package:shared_preferences/shared_preferences.dart';

import '../sync/client_app_state_push_bridge.dart';

/// Время последнего подтверждённого пробега (сохранение в карточке) — для напоминания раз в 15 дней.
abstract final class MileagePromptStorage {
  static String _key(String userId, String carId) => 'mileage_saved_at_${userId}_$carId';

  /// Для машин без ключа: один раз проставить «сейчас», чтобы не показывать диалог сразу после обновления.
  static Future<void> migrateMissingForCars(
    SharedPreferences prefs,
    String userId,
    Iterable<String> carIds,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final id in carIds) {
      if (id.isEmpty) continue;
      final k = _key(userId, id);
      if (!prefs.containsKey(k)) {
        await prefs.setInt(k, now);
      }
    }
    scheduleClientAppStatePush();
  }

  static Future<void> markNow(SharedPreferences prefs, String userId, String carId) async {
    if (userId.isEmpty || carId.isEmpty) return;
    await prefs.setInt(_key(userId, carId), DateTime.now().millisecondsSinceEpoch);
    scheduleClientAppStatePush();
  }

  /// true, если с последнего сохранения пробега прошло ≥ 15 дней.
  static bool shouldPrompt(SharedPreferences prefs, String userId, String carId) {
    if (userId.isEmpty || carId.isEmpty) return false;
    final v = prefs.getInt(_key(userId, carId));
    if (v == null) return false;
    final last = DateTime.fromMillisecondsSinceEpoch(v);
    return DateTime.now().difference(last).inDays >= 15;
  }
}
