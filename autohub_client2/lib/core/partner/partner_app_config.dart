/// Партнёрский API заявок (ОСАГО и др.), отдельно от MP-Servis.
/// Сборка: `--dart-define=PARTNER_API_BASE_URL=https://example.com/api/v1`
/// `--dart-define=PARTNER_API_TOKEN=...` `--dart-define=PARTNER_OSAGO_PRODUCT_ID=123`
///
/// Имена полей в теле POST `/orders` можно переопределить под схему партнёра.
class PartnerAppConfig {
  PartnerAppConfig._();

  static const String _baseFromEnv = String.fromEnvironment(
    'PARTNER_API_BASE_URL',
    defaultValue: '',
  );

  static const String apiToken = String.fromEnvironment(
    'PARTNER_API_TOKEN',
    defaultValue: '',
  );

  static const int osagoProductId = int.fromEnvironment(
    'PARTNER_OSAGO_PRODUCT_ID',
    defaultValue: 0,
  );

  static const String fieldFio = String.fromEnvironment(
    'PARTNER_OSAGO_FIELD_FIO',
    defaultValue: 'full_name',
  );
  static const String fieldPhone = String.fromEnvironment(
    'PARTNER_OSAGO_FIELD_PHONE',
    defaultValue: 'phone',
  );
  static const String fieldEmail = String.fromEnvironment(
    'PARTNER_OSAGO_FIELD_EMAIL',
    defaultValue: 'email',
  );
  static const String fieldPlate = String.fromEnvironment(
    'PARTNER_OSAGO_FIELD_PLATE',
    defaultValue: 'license_plate',
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
