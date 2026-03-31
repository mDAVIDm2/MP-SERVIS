import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'autohub_firebase_options.dart';

/// Инициализация Firebase: сначала `dart-define` (см. [AutohubFirebaseOptions]),
/// иначе нативный конфиг (`android/app/google-services.json` при подключённом плагине).
Future<bool> ensureFirebaseAppInitialized() async {
  if (Firebase.apps.isNotEmpty) return true;
  try {
    final opts = AutohubFirebaseOptions.currentPlatform;
    if (opts != null) {
      await Firebase.initializeApp(options: opts);
    } else {
      await Firebase.initializeApp();
    }
    return true;
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('[Firebase] initializeApp не удалось: $e');
      debugPrint('$st');
    }
    return false;
  }
}
