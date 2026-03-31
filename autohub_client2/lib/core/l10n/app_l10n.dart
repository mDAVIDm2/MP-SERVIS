import 'dart:ui';

/// Строки приложения для RU/EN. Используется с [Locale] из [localeProvider].
class AppL10n {
  AppL10n(this.locale);
  final Locale locale;

  bool get isEn => locale.languageCode == 'en';

  // Нижняя навигация
  String get navGarage => isEn ? 'Garage' : 'Гараж';
  String get navServices => isEn ? 'Services' : 'Сервисы';
  String get navSearch => isEn ? 'Search' : 'Поиск';
  String get navChats => isEn ? 'Chats' : 'Чаты';
  String get navProfile => isEn ? 'Profile' : 'Профиль';

  // Профиль — заголовки и секции
  String get profileTitle => isEn ? 'Profile' : 'Профиль';
  String get guest => isEn ? 'Guest' : 'Гость';
  String get editProfile => isEn ? 'Edit profile' : 'Редактировать профиль';
  String get myCars => isEn ? 'My cars' : 'Мои автомобили';
  String get add => isEn ? 'Add' : 'Добавить';
  String get settings => isEn ? 'Settings' : 'Настройки';
  String get support => isEn ? 'Support' : 'Поддержка';
  String get account => isEn ? 'Account' : 'Аккаунт';

  // Настройки
  String get sortByCar => isEn ? 'Sort by car' : 'Сортировать по машине';
  String get sortByCarSubtitle => isEn
      ? 'Orders, services, home — by selected car'
      : 'Заказы, сервисы, главный экран — по выбранному авто';
  String get maps => isEn ? 'Maps' : 'Карты';
  String get notifications => isEn ? 'Notifications' : 'Уведомления';
  String get maintenanceReminders => isEn ? 'Maintenance reminders' : 'Напоминания о ТО';
  String get units => isEn ? 'Units' : 'Единицы измерения';
  String get theme => isEn ? 'Theme' : 'Тема';
  String get themeDark => isEn ? 'Dark' : 'Тёмная';
  String get language => isEn ? 'Language' : 'Язык';
  String get security => isEn ? 'Security' : 'Безопасность';

  // Поддержка
  String get faq => isEn ? 'FAQ' : 'Частые вопросы (FAQ)';
  String get writeSupport => isEn ? 'Contact support' : 'Написать в поддержку';
  String get rateApp => isEn ? 'Rate app' : 'Оценить приложение';
  String get about => isEn ? 'About' : 'О приложении';

  // Аккаунт
  String get logout => isEn ? 'Log out' : 'Выйти из аккаунта';
  String get logoutButton => isEn ? 'Log out' : 'Выйти';
  String get logoutConfirmTitle => isEn ? 'Log out?' : 'Выйти из аккаунта?';
  String get logoutConfirmMessage => isEn
      ? 'Token and profile data are stored on this device. After logout you can sign in with another number.'
      : 'Токен и данные профиля хранятся на этом устройстве (SharedPreferences). После выхода можно войти под другим номером.';
  String get cancel => isEn ? 'Cancel' : 'Отмена';
  String get logoutDone => isEn ? 'You have logged out' : 'Вы вышли из аккаунта';
  String get authDataNote => isEn
      ? 'Auth data is stored on this device only.'
      : 'Данные авторизации сохраняются только на этом устройстве (локально).';

  // Выбор языка
  String get languageRussian => isEn ? 'Russian' : 'Русский';
  String get languageEnglish => 'English';
  String get languageSetRu => isEn ? 'Language: Russian' : 'Язык: Русский';
  String get languageSetEn => 'Language: English';

  // Снекбары / подсказки
  String get unitsSetting => isEn ? 'Units setting' : 'Настройка единиц';
  String get themeSetting => isEn ? 'Theme selection' : 'Выбор темы';
  String get supportChat => isEn ? 'Support chat' : 'Чат поддержки';
  String get rateRedirect => isEn ? 'Redirect to store' : 'Перенаправление в магазин';
}
