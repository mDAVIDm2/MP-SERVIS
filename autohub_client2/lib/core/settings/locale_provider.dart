import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_provider.dart';

const _kLocaleCode = 'app_locale';

/// Поддерживаемые языки приложения.
enum AppLocale {
  ru('ru', 'Русский'),
  en('en', 'English');

  final String code;
  final String label;
  const AppLocale(this.code, this.label);

  Locale get locale => Locale(code);
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  return LocaleNotifier(prefs);
});

class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier(this._prefs) : super(_load(_prefs));
  final SharedPreferences? _prefs;

  static Locale? _load(SharedPreferences? prefs) {
    if (prefs == null) return null;
    final code = prefs.getString(_kLocaleCode);
    if (code == null) return null;
    final app = AppLocale.values.cast<AppLocale?>().firstWhere(
      (e) => e?.code == code,
      orElse: () => null,
    );
    return app?.locale;
  }

  Future<void> setLocale(AppLocale appLocale) async {
    state = appLocale.locale;
    await _prefs?.setString(_kLocaleCode, appLocale.code);
  }

  /// Текущая выбранная локаль для отображения в UI.
  AppLocale get currentAppLocale {
    final loc = state;
    if (loc == null) return AppLocale.ru;
    for (final e in AppLocale.values) {
      if (e.code == loc.languageCode) return e;
    }
    return AppLocale.ru;
  }
}
