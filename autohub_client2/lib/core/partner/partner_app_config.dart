/// Партнёрский API заявок (ОСАГО и др.), отдельно от MP-Servis.
/// Сборка: `--dart-define=PARTNER_API_BASE_URL=https://example.com/api/v1`
/// `--dart-define=PARTNER_API_TOKEN=...` `--dart-define=PARTNER_OSAGO_PRODUCT_ID=123`
///
/// Имена полей в теле POST `/orders` можно переопределить под схему партнёра.
///
/// **ОСАГО (витрина Pampadu)** загружается в приложении в WebView, URL:
/// `--dart-define=PAMPADU_OSAGO_WIDGET_URL=https://b2c.pampadu.ru/index.html#...`
class PartnerAppConfig {
  PartnerAppConfig._();

  /// Pampadu B2C-виджет: тот же `src`, что в iframe на сайте партнёра.
  static const String pampaduOsagoWidgetUrl = String.fromEnvironment(
    'PAMPADU_OSAGO_WIDGET_URL',
    defaultValue:
        'https://b2c.pampadu.ru/index.html#7d4b0b1c-cb14-4de1-824a-e55c49ac4fc5',
  );

  static String get pampaduOsagoWidgetUrlTrimmed => pampaduOsagoWidgetUrl.trim();
  static bool get hasPampaduOsagoUrl => pampaduOsagoWidgetUrlTrimmed.isNotEmpty;

  static const String _baseFromEnv = String.fromEnvironment(
    'PARTNER_API_BASE_URL',
    defaultValue: '',
  );

  static const String apiToken = String.fromEnvironment(
    'PARTNER_API_TOKEN',
    defaultValue: '',
  );

  /// Из JSON `--dart-define-from-file` приходит строка `"481"`; [int.fromEnvironment] тогда даёт 0.
  static const String _osagoProductIdFromEnv = String.fromEnvironment(
    'PARTNER_OSAGO_PRODUCT_ID',
    defaultValue: '',
  );

  static int get osagoProductId => int.tryParse(_osagoProductIdFromEnv.trim()) ?? 0;

  /// Схема rko-partner.com (JSONForms): транслит ключей в теле POST `/orders`.
  static const String fieldFio = String.fromEnvironment(
    'PARTNER_OSAGO_FIELD_FIO',
    defaultValue: 'fio_straxovatelia',
  );
  static const String fieldPhone = String.fromEnvironment(
    'PARTNER_OSAGO_FIELD_PHONE',
    defaultValue: 'telefon_straxovatelia',
  );
  static const String fieldEmail = String.fromEnvironment(
    'PARTNER_OSAGO_FIELD_EMAIL',
    defaultValue: 'elektronnaia_pocta_straxovatelia',
  );
  static const String fieldPlate = String.fromEnvironment(
    'PARTNER_OSAGO_FIELD_PLATE',
    defaultValue: 'gosudarstvennyi_nomer_avtomobilia',
  );

  static String get apiBaseUrl {
    var u = _baseFromEnv.trim();
    if (u.isEmpty) {
      return 'https://rko-partner.com/api/v1';
    }
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  static bool get hasToken => apiToken.trim().isNotEmpty;

  static bool get canSubmitOsago => hasToken && osagoProductId > 0;
}
