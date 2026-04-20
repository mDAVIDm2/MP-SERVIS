import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_provider.dart' show sharedPreferencesProvider;
import '../sync/client_app_state_push_bridge.dart';

const String kClientThemeModeKey = 'client_theme_mode';

/// Режим темы клиентского приложения (сохраняется в SharedPreferences).
final themeModeProvider = NotifierProvider<ClientThemeModeNotifier, ThemeMode>(ClientThemeModeNotifier.new);

class ClientThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final asyncPrefs = ref.watch(sharedPreferencesProvider);
    return asyncPrefs.when(
      data: _readMode,
      loading: () => ThemeMode.dark,
      error: (_, __) => ThemeMode.dark,
    );
  }

  ThemeMode _readMode(SharedPreferences p) {
    switch (p.getString(kClientThemeModeKey)) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    final SharedPreferences prefs = await ref.read(sharedPreferencesProvider.future);
    final s = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      ThemeMode.dark => 'dark',
    };
    await prefs.setString(kClientThemeModeKey, s);
    state = mode;
    scheduleClientAppStatePush();
  }
}
