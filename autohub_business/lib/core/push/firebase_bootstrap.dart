import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// FCM для Android/iOS (проект Firebase Business, `google-services.json` в android/app/).
Future<bool> ensureFirebaseAppInitialized() async {
  if (kIsWeb) return false;
  if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
    return false;
  }
  if (Firebase.apps.isNotEmpty) return true;
  try {
    await Firebase.initializeApp();
    return true;
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('[Business Firebase] initializeApp: $e');
      debugPrint('$st');
    }
    return false;
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await ensureFirebaseAppInitialized();
}
