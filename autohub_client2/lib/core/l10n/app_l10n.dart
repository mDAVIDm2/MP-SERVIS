import 'dart:ui';

import 'package:intl/intl.dart';

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
  String get themeLight => isEn ? 'Light' : 'Светлая';
  String get themeSystem => isEn ? 'As in system' : 'Как в системе';
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
      ? 'You will need to sign in again to use the app. Your account stays on the server — orders, garage, chats and profile sync when you log in on any device.'
      : 'Для работы с приложением потребуется войти снова. Аккаунт на сервере сохраняется — заказы, гараж, чаты и профиль подтянутся при входе с любого устройства.';
  String get cancel => isEn ? 'Cancel' : 'Отмена';
  String get logoutDone => isEn ? 'You have logged out' : 'Вы вышли из аккаунта';

  // Выбор языка
  String get languageRussian => isEn ? 'Russian' : 'Русский';
  String get languageEnglish => 'English';
  String get languageSetRu => isEn ? 'Language: Russian' : 'Язык: Русский';
  String get languageSetEn => 'Language: English';

  // Снекбары / подсказки
  String get unitsSetting => isEn ? 'Units setting' : 'Настройка единиц';
  String get themeSetting => isEn ? 'Theme selection' : 'Выбор темы';
  String get themeSetDark => isEn ? 'Theme: dark' : 'Тема: тёмная';
  String get themeSetLight => isEn ? 'Theme: light' : 'Тема: светлая';
  String get themeSetSystem => isEn ? 'Theme: as in system' : 'Тема: как в системе';
  String get supportChat => isEn ? 'Support chat' : 'Чат поддержки';
  String get rateRedirect => isEn ? 'Redirect to store' : 'Перенаправление в магазин';

  /// Для intl (`en_US` / `ru_RU`).
  String get intlLocale => isEn ? 'en_US' : 'ru_RU';

  // Общие
  String get save => isEn ? 'Save' : 'Сохранить';
  String get delete => isEn ? 'Delete' : 'Удалить';
  String get edit => isEn ? 'Edit' : 'Изменить';
  String get errorLoading => isEn ? 'Failed to load' : 'Ошибка загрузки';
  String errorColon(Object e) => isEn ? 'Error: $e' : 'Ошибка: $e';

  // Гараж (экран)
  String get garageScreenTitle => isEn ? 'Garage' : 'Гараж';
  String get maintenanceRecommendations => isEn ? 'Maintenance tips' : 'Рекомендации по обслуживанию';
  String get lastActivity => isEn ? 'Recent activity' : 'Последняя активность';
  String get showAllArrow => isEn ? 'See all →' : 'Показать все →';
  String get noOrdersForThisCar => isEn ? 'No orders for this vehicle' : 'Нет заказов по этому автомобилю';

  // Напоминания — список / экран
  String get maintWhenShowTooltip => isEn ? 'When to show reminders' : 'Когда показывать напоминание';
  String get maintAddCarFirst => isEn ? 'Add a vehicle in Garage' : 'Добавьте автомобиль в Гараж';
  String get maintIntroShort => isEn ? 'Summary' : 'Коротко';
  String get maintIntroLine1 => isEn
      ? 'For each reminder you can set an interval by mileage, by time, or both.'
      : 'Для каждого напоминания можно задать интервал по пробегу, по сроку или оба сразу.';
  String get maintIntroLine2 => isEn
      ? 'History is filled from completed orders and can be added manually.'
      : 'История подтягивается из завершённых заказов и может добавляться вручную.';
  /// Одна строка вместо двух абзацев на экране напоминаний.
  String get maintIntroOneLine => isEn
      ? 'Intervals by mileage and/or time. History from orders or manual entries.'
      : 'Пробег и/или срок. История — из заказов или вручную.';
  String get maintOrdersLoadFailedHint => isEn
      ? 'Orders not loaded — auto history unavailable. Reminders on device still work.'
      : 'Заказы не загрузились — автоподстановка из них недоступна. Напоминания на устройстве работают.';
  String get maintLogDoneTitle => isEn ? 'Log completed service' : 'Записать выполненное ТО';
  String get maintLogDoneSubtitle => isEn ? 'Date, mileage, jobs' : 'Дата, пробег, виды работ';
  String get maintHideOtherCars => isEn ? 'Hide other vehicles' : 'Скрыть другие машины';
  String maintShowOtherCars(int n) =>
      isEn ? 'Show other vehicles ($n)' : 'Показать другие машины ($n)';
  String get maintWhenShowRecTitle => isEn ? 'When to show recommendations' : 'Когда показывать рекомендации';
  String get maintWhenShowRecHint => isEn
      ? 'Show the block when the next service is within:'
      : 'Показывать блок, когда до замены осталось:';
  String get maintKmThresholdLabel => isEn ? 'Kilometers (100–10,000)' : 'Километров (100–10 000)';
  String get maintDaysThresholdLabel => isEn ? 'Days by date (1–90)' : 'Дней по сроку (1–90)';
  String get addReminder => isEn ? 'Add reminder' : 'Добавить напоминание';
  String get chooseServiceTitle => isEn ? 'Choose a service' : 'Выберите услугу';
  String get chooseServiceSubtitle => isEn ? 'Grouped by section' : 'По разделам';
  String get searchByNameOrDesc => isEn ? 'Search by name or description' : 'Поиск по названию или описанию';
  String get otherSection => isEn ? 'Other' : 'Другое';
  String get nothingFound => isEn ? 'Nothing found' : 'Ничего не найдено';
  String addedLabel(String name) => isEn ? 'Added: $name' : 'Добавлено: $name';

  String get maintSectionEngine => isEn ? 'Engine and fluids' : 'Двигатель и жидкости';
  String get maintSectionBrakes => isEn ? 'Brakes, tires, chassis' : 'Тормоза, шины, ходовая';
  String get maintSectionElectric => isEn ? 'Electrics, inspection, general' : 'Электрика, осмотр, общее';

  // Запись о ТО (нижний лист)
  String get maintRecordSheetTitle => isEn ? 'Service record' : 'Запись о ТО';
  String get maintRecordSheetHint =>
      isEn ? 'Several job types — one date and mileage.' : 'Несколько видов работ — одна дата и пробег.';
  String get vehicle => isEn ? 'Vehicle' : 'Автомобиль';
  String get jobTypeRequired => isEn ? 'Job types *' : 'Виды работ *';
  String get searchByName => isEn ? 'Search by name' : 'Поиск по названию';
  String get workDate => isEn ? 'Service date' : 'Дата работ';
  String get mileageKmRequired => isEn ? 'Odometer, km *' : 'Пробег, км *';
  String get digitsOnlyHint => isEn ? 'Digits only' : 'Только цифры';
  String get placeOptional => isEn ? 'Where (optional)' : 'Где делали (необязательно)';
  String get serviceNameHint => isEn ? 'Shop name' : 'Название сервиса';
  String get saveRecord => isEn ? 'Save record' : 'Сохранить запись';
  String get selectJobType => isEn ? 'Select a job type' : 'Выберите вид работ';
  String get selectAtLeastOneJobType =>
      isEn ? 'Select at least one job type' : 'Выберите один или несколько видов работ';
  String get enterValidMileage => isEn ? 'Enter a valid odometer reading' : 'Укажите корректный пробег';
  String recordAdded(String jobTitle) => isEn ? 'Record added: $jobTitle' : 'Запись добавлена: $jobTitle';
  String recordsAddedCount(int n) =>
      isEn ? 'Added $n service records' : 'Добавлено записей: $n';

  // Деталь напоминания
  String get replacementHistory => isEn ? 'History' : 'История';
  String get maintHistoryEmpty =>
      isEn ? 'No entries yet. Add or wait for orders.' : 'Пока пусто. Добавьте сами или из заказов.';
  String get removeReminderFromList => isEn ? 'Remove reminder' : 'Убрать напоминание';
  String get settingsSaved => isEn ? 'Settings saved' : 'Настройки сохранены';
  String get removeReminderTitle => isEn ? 'Remove reminder?' : 'Убрать напоминание?';
  String get removeReminderBody =>
      isEn ? 'Intervals reset. History stays.' : 'Сброс настроек. История останется.';
  String get removeAction => isEn ? 'Remove' : 'Убрать';
  String get oilQuickSetupHint =>
      isEn ? 'Set intervals below.' : 'Интервалы — ниже.';
  String get reminderNotAdded =>
      isEn ? 'Pick a service from the list.' : 'Выберите услугу в списке.';
  String get lastReplacement => isEn ? 'Last' : 'Было';
  String get noDataAddRecord => isEn ? 'No data' : 'Нет данных';
  String get remaining => isEn ? 'Remaining' : 'Осталось';
  String get nextReplacement => isEn ? 'Next' : 'Дальше';
  String get onMileagePrefix => isEn ? 'at ' : 'на ';
  String get untilPrefix => isEn ? 'by ' : 'до ';
  String overdueDays(int d) => isEn ? 'overdue by $d d' : 'просрочено на $d дн.';
  String approxDays(int d) => isEn ? '≈ $d d' : '≈ $d дн.';
  String get overdueKmAndDate => isEn ? 'Overdue (both)' : 'Просрочено: оба';
  String get overdueKm => isEn ? 'Overdue (mileage)' : 'Просрочено: пробег';
  String get overdueDate => isEn ? 'Overdue (date)' : 'Просрочено: срок';
  String get reminderSetupTitle => isEn ? 'Intervals' : 'Интервалы';
  String get reminderEnabled => isEn ? 'Notifications' : 'Уведомления';
  String get reminderEnabledSubtitle =>
      isEn ? 'When off, calculations are still kept' : 'При выключении расчёты сохраняются';
  String get reminderOffHint => isEn ? 'Off' : 'Выключено';
  String get intervalHint => isEn
      ? 'You can use mileage, time, or both. Whichever comes first applies.'
      : 'Можно использовать пробег, срок или оба критерия. Сработает то, что наступит раньше.';
  String get intervalByMileage => isEn ? 'Mileage' : 'Пробег';
  String get intervalByTime => isEn ? 'Time' : 'Срок';
  String everyKm(String km) => isEn ? 'Every $km km' : 'Каждые $km км';
  String everyMonths(String m) => isEn ? 'Every $m mo' : 'Раз в $m мес.';
  String get kmBetween => isEn ? 'km' : 'км';
  String get monthsBetween => isEn ? 'mo' : 'мес';
  String get fromOrder => isEn ? 'From order' : 'Из заказа';
  String get deleteRecordTitle => isEn ? 'Delete entry?' : 'Удалить запись?';
  String get kmUnit => isEn ? 'km' : 'км';
  String mileageValue(int km) {
    final sep = NumberFormat.decimalPattern(intlLocale);
    return '${sep.format(km)} $kmUnit';
  }

  // Компактная плитка напоминания
  String get configureIntervals => isEn ? 'Set intervals' : 'Задайте интервал';
  String get reminderDisabled => isEn ? 'Off' : 'Выкл.';
  String get addReplacementDate => isEn ? 'Add last service date' : 'Укажите дату замены';
  String get mileageOverdue => isEn ? 'Mileage overdue' : 'Пробег просрочен';
  String get dateOverdue => isEn ? 'Date overdue' : 'Срок вышел';
  String get openCard => isEn ? 'Tap for details' : 'Подробнее';

  // Карты (настройки)
  String get mapInSearchTab => isEn ? 'Map on Search tab' : 'Карта во вкладке «Поиск»';
  String get routingApp => isEn ? 'App for directions' : 'Приложение для маршрутов';
  String get noMapsInstalled => isEn ? 'No map apps installed' : 'Нет установленных карт';
  String get navigatorSaved => isEn ? 'Navigator saved' : 'Навигатор сохранён';
  String get chooseNavigator => isEn ? 'Choose navigator' : 'Выберите навигатор';
  String get navigatorForRoute => isEn ? 'Navigator for route' : 'Навигатор для маршрута';

  // Чаты (список)
  String get chatsTitle => isEn ? 'Chats' : 'Чаты';
  String get searchChatsHint => isEn ? 'Search chats…' : 'Поиск по чатам...';
  String get chatsActive => isEn ? 'Active' : 'Активные';
  String get chatsArchived => isEn ? 'Archived' : 'Завершённые';
  String get noChatsTitle => isEn ? 'No chats yet' : 'Нет чатов';
  String get noChatsSubtitle => isEn
      ? 'Chats appear when you book at a shop.\nFind a service in Search.'
      : 'Чаты создаются при записи в автосервис.\nЗакажите услугу в разделе Поиск.';
  String get findService => isEn ? 'Find a shop' : 'Найти сервис';
  String get pinnedSection => isEn ? 'PINNED' : 'ЗАКРЕПЛЁННЫЕ';
  String get allChatsSection => isEn ? 'ALL CHATS' : 'ВСЕ ЧАТЫ';
  String get orderOpenFailed => isEn
      ? 'Could not open order. Check your connection.'
      : 'Не удалось открыть заказ. Проверьте подключение.';
  String get needsApproval => isEn ? 'Approval required' : 'Требуется согласование';
  String get chatYouPrefix => isEn ? 'You: ' : 'Вы: ';

  // Рекомендации в гараже (срочные ТО)
  String get garageRecMoreInCard => isEn ? 'More in the reminder' : 'Подробнее в карточке';
  String get garageRecDetails => isEn ? 'Details' : 'Подробнее';
  String get garageRecBook => isEn ? 'Book' : 'Записаться';
  String maintUrgentKmOverdue(String km) =>
      isEn ? 'Mileage: overdue by $km km' : 'По пробегу: просрочено на $km км';
  String maintUrgentKmLeft(String km) =>
      isEn ? 'Mileage: ≈ $km km left' : 'По пробегу: осталось ≈ $km км';
  String maintUrgentNextKm(String km) =>
      isEn ? 'Next service at ≈ $km km' : 'Замена потребуется на ≈ $km км';
  String get maintUrgentDateOverdueLine => isEn ? 'By date: overdue' : 'По сроку: просрочено';
  String maintUrgentDateLeftLine(int d) =>
      isEn ? 'By date: ≈ $d d left' : 'По сроку: осталось ≈ $d дн.';
  String maintUrgentPlanUntil(String date) =>
      isEn ? 'Planned by: $date' : 'Плановая дата: до $date';

  // Карточка напоминания в гараже (модель CarReminder)
  String reminderOverdueMileage(String mileageStr) =>
      isEn ? 'Overdue by $mileageStr' : 'Просрочено на $mileageStr';
  String reminderLeftMileage(String mileageStr) =>
      isEn ? '≈ $mileageStr left' : 'Осталось ~$mileageStr';

  // Аналитика (экран и экспорт)
  String get analyticsTitle => isEn ? 'Analytics' : 'Аналитика';
  String get analyticsAddCarToGarage =>
      isEn ? 'Add a vehicle in Garage' : 'Добавьте автомобиль в Гараж';
  String get analyticsExportTooltip => isEn ? 'Export table (CSV)' : 'Экспорт таблицы (CSV)';
  String get analyticsDataSection => isEn ? 'Data' : 'Данные';
  String get analyticsExportCsv => isEn ? 'Export CSV' : 'Экспорт CSV';
  String get analyticsNoOrdersFiltered =>
      isEn ? 'No orders match the selected period and filters.' : 'Нет заказов в выбранном периоде и фильтрах.';
  String get analyticsOrdersSection => isEn ? 'Orders' : 'Заказы';
  String get analyticsOrgKindUnknown => isEn ? 'Type not specified' : 'Тип не указан';
  String get analyticsPieNoPositive =>
      isEn ? 'No positive values to display on the chart.' : 'Нет положительных значений для диаграммы.';
  String analyticsExportError(Object e) => isEn ? 'Export: $e' : 'Экспорт: $e';

  String get analyticsPeriodLabel => isEn ? 'Period' : 'Период';
  String analyticsPeriodChipMonths(int m) => isEn ? '$m mo' : '$m мес';
  String get analyticsAllTimeChip => isEn ? 'All time' : 'Всё время';
  String get analyticsOrgFilterLabel => isEn ? 'Organization type (filter)' : 'Тип организации (фильтр)';
  String get analyticsAllOrgTypes => isEn ? 'All types' : 'Все типы';
  String get analyticsGroupingLabel => isEn ? 'Group by' : 'Группировка';
  String get analyticsGroupByMonth => isEn ? 'By month' : 'По месяцам';
  String get analyticsGroupByOrgKind => isEn ? 'By organization type' : 'По типу организации';
  String get analyticsGroupByServiceCategory => isEn ? 'By service category' : 'По категории услуг';
  String get analyticsGroupByServiceCategoryHint => isEn
      ? 'By service category (API catalog, otherwise heuristics)'
      : 'По категории услуг (справочник API, иначе эвристика)';
  String get analyticsCatalogLoading =>
      isEn ? 'Loading service catalog from server…' : 'Загрузка справочника услуг с сервера…';
  String get analyticsMetricLabel => isEn ? 'Metric' : 'Показатель';
  String get analyticsFormatLabel => isEn ? 'Format' : 'Формат';
  String get analyticsChartBars => isEn ? 'Bars' : 'Столбцы';
  String get analyticsChartPie => isEn ? 'Pie' : 'Круг';
  String get analyticsChartTable => isEn ? 'Table' : 'Таблица';
  /// Короткие подписи для сегментов без некрасивого переноса.
  String get analyticsChartBarsShort => isEn ? 'Hist' : 'Гист.';
  String get analyticsChartPieShort => isEn ? 'Pie' : 'Круг';
  String get analyticsChartTableShort => isEn ? 'Tbl' : 'Табл.';
  String get analyticsAddChartBlock => isEn ? 'Add chart' : 'Добавить диаграмму';
  String get analyticsRemoveChartBlock => isEn ? 'Remove chart' : 'Удалить диаграмму';

  String get analyticsMetricTotalSpend => isEn ? 'Total spend' : 'Сумма расходов';
  String get analyticsMetricOrderCount => isEn ? 'Order count' : 'Число заказов';
  String get analyticsMetricAvgCheck => isEn ? 'Average check' : 'Средний чек';
  String get analyticsMetricAvgMonthlyInGroup =>
      isEn ? 'Average monthly spend (within group)' : 'Средний расход за месяц (в группе)';
  String get analyticsMetricLongOrderLines =>
      isEn ? 'Order count / line items' : 'Количество заказов / позиций';

  String get analyticsMetricShortSumRub => isEn ? 'Sum, ₽' : 'Сумма, ₽';
  String get analyticsMetricShortOrders => isEn ? 'Orders' : 'Заказов';
  String get analyticsMetricShortAvgRub => isEn ? 'Avg check, ₽' : 'Средний чек, ₽';
  String get analyticsMetricShortAvgMonthly => isEn ? 'Avg / mo' : 'Усл. / мес.';

  String get analyticsExportPeriodAll => isEn ? 'All time' : 'Всё время';
  String analyticsExportPeriodLastMonths(int n) => isEn ? 'Last $n mo' : 'Последние $n мес.';

  String get analyticsKpiSummaryPrefix => isEn ? 'Summary' : 'Сводка';
  String analyticsKpiPeriodAll() => isEn ? 'all time' : 'за всё время';
  String analyticsKpiPeriodMonths(int n) => isEn ? 'for $n mo' : 'за $n мес.';
  String get analyticsKpiSpend => isEn ? 'Spend' : 'Расходы';
  String get analyticsKpiOrders => isEn ? 'Orders' : 'Заказов';
  String get analyticsKpiAvgCheck => isEn ? 'Avg check' : 'Средний чек';
  String get analyticsKpiAvgPerMonth => isEn ? 'Avg / month' : 'В среднем / мес.';

  String get analyticsGroupColumn => isEn ? 'Group' : 'Группа';

  String get analyticsCsvSectionLine => isEn ? 'MP-Servis;Analytics' : 'MP-Servis;Аналитика';
  String get analyticsCsvVehicle => isEn ? 'Vehicle' : 'Автомобиль';
  String get analyticsCsvPeriod => isEn ? 'Period' : 'Период';
  String get analyticsCsvGrouping => isEn ? 'Grouping' : 'Группировка';
  String get analyticsCsvMetric => isEn ? 'Metric' : 'Показатель';
  String get analyticsCsvOrgFilter => isEn ? 'Organization type filter' : 'Фильтр типа точки';
  String get analyticsShareSubject => isEn ? 'MP-Servis — analytics' : 'MP-Servis — аналитика';

  // Карточка «Аналитика» в профиле
  String get analyticsPreviewTitle => analyticsTitle;
  String get analyticsPreviewTotalSpend => isEn ? 'Total spend' : 'Общие расходы';
  String get analyticsPreviewAvgCheck => isEn ? 'Average check' : 'Средний чек';
  String get analyticsPreviewSeeMore => isEn ? 'Details →' : 'Подробнее →';
  String get carShortLabel => isEn ? 'Car' : 'Авто';

  // Диалог обновления пробега (MainShell)
  String get mileagePromptTitle => isEn ? 'Update mileage' : 'Обновите пробег';
  String mileagePromptBody(String carLabel) => isEn
      ? 'Mileage for $carLabel has not been updated in a while. Enter the current odometer (km).'
      : 'Для $carLabel давно не вводился пробег. Укажите актуальное значение (км).';
  String get mileageKmFieldLabel => isEn ? 'Odometer, km' : 'Пробег, км';
  String get later => isEn ? 'Later' : 'Позже';
  String get mileageSaveFailed => isEn ? 'Could not save mileage' : 'Не удалось сохранить пробег';

  // Чаты (дополнительно к chatsTitle и т.д.)
  String chatsArchiveTitle(int n) => isEn ? 'Archive ($n)' : 'Архив ($n)';
  String get chatsBackToList => chatsTitle;
  String get chatsNoInArchive => isEn ? 'No chats in archive' : 'Нет чатов в архиве';
  String get chatsArchiveEmptyHint => isEn
      ? 'Swipe a chat right in the main list to move it to the archive.'
      : 'Смахните чат вправо в основном списке, чтобы перенести в архив.';
  String get chatsPinnedHeading =>
      isEn ? '📌 PINNED' : '📌 ЗАКРЕПЛЁННЫЕ';
  String get chatsArchivedSwipe => isEn ? 'Archive' : 'В архив';
  String get chatsArchivedRestoreSwipe => isEn ? 'Restore from archive' : 'Вернуть из архива';
  String get supportShortLabel => isEn ? 'Support' : 'Поддержка';
  String get approvalRequiredShort => isEn ? '⚠️ Approval required' : '⚠️ Требуется согласование';

  // Заказ: блок сервиса
  String bookingWithMode(String modeLabel) =>
      isEn ? 'Booking: $modeLabel' : 'Запись: $modeLabel';
  String get callService => isEn ? 'Call' : 'Позвонить';
  String get directionsToService => isEn ? 'Directions' : 'Маршрут';

  // Экран заказа
  String orderDetailTitle(String orderNumber) => isEn ? 'Order #$orderNumber' : 'Заказ #$orderNumber';
  String get orderWorksheetPdfTooltip => isEn ? 'Work order (PDF)' : 'Заказ-наряд (PDF)';
  String get orderOpenChatTooltip => isEn ? 'Open chat' : 'Открыть чат';
  String get orderSectionVehicle => vehicle;
  String get orderSectionService => isEn ? 'Shop' : 'Сервис';
  String get orderSectionDateTime => isEn ? 'Date and time' : 'Дата и время';
  String get orderSectionWorks => isEn ? 'Services' : 'Работы';
  String get orderSectionComment => isEn ? 'Comment' : 'Комментарий';
  String get orderAdditionalPending => isEn ? 'Additional (pending approval)' : 'Дополнительно (на согласовании)';
  String get orderAdditionalAfterApproval =>
      isEn ? 'Added (after approval)' : 'Добавлено (после согласования)';
  String get orderStepBooked => isEn ? 'Booked' : 'Записан';
  String get orderStepConfirmed => isEn ? 'Confirmed' : 'Подтверждён';
  String get orderStepInProgress => isEn ? 'In progress' : 'В работе';
  String get orderStepReady => isEn ? 'Ready' : 'Готов';
  String get orderStepDone => isEn ? 'Completed' : 'Завершён';
  String get orderApprovalExtraTitle =>
      isEn ? 'Additional work needs approval' : 'Требуется согласование доп.работ';
  String get orderApprovalExtraSubtitle =>
      isEn ? 'Confirm or decline in chat' : 'Подтвердите или отклоните в чате';
  String get orderGoToChat => isEn ? 'Open chat' : 'Перейти в чат';
  String get orderStoNotOnMap => isEn ? 'Shop address is not on the map' : 'Адрес сервиса не привязан к карте';
  String get phoneNotListed => isEn ? 'No phone number' : 'Номер не указан';
  String get pickPhoneNumber => isEn ? 'Choose a number' : 'Выберите номер';
  String orderEstimatedEnd(String time) =>
      isEn ? 'Estimated finish: $time' : 'Ориентировочное окончание: $time';
  String get orderExpectedTimeLabel => isEn ? 'Estimated time' : 'Ожидаемое время';
  String get orderJobsDoneLabel => isEn ? 'jobs done' : 'работ выполнено';
  String get orderSubtotalWorks => isEn ? 'Services:' : 'Работы:';
  String get orderSubtotalAdditional => isEn ? 'Additional:' : 'Дополнительно:';
  String get orderGrandTotal => isEn ? 'Total' : 'Итого';
  String get orderWorkPhotos => isEn ? 'Work photos' : 'Фото работ';
  String get orderGoToApproval => isEn ? 'Go to approval' : 'Перейти к согласованию';
  String get orderLeaveReview => isEn ? 'Leave a review' : 'Оставить отзыв';
  String get orderRepeat => isEn ? 'Repeat order' : 'Повторить заказ';
  String get orderCancelBooking => isEn ? 'Cancel booking' : 'Отменить запись';
  String get orderCancelConfirmTitle => isEn ? 'Cancel booking?' : 'Отменить запись?';
  String get orderCancelCannotUndo =>
      isEn ? 'This action cannot be undone.' : 'Эту операцию нельзя отменить.';
  String get orderNo => isEn ? 'No' : 'Нет';
  String get orderCancelledToast => isEn ? 'Booking cancelled' : 'Запись отменена';
  String get orderCancelFailed =>
      isEn ? 'Could not cancel. Check your connection.' : 'Не удалось отменить запись. Проверьте сеть.';
  String get orderLoadStoFailed => isEn ? 'Could not load shop data' : 'Не удалось загрузить данные сервиса';
  String get orderOpenStoFailed => isEn ? 'Could not open the shop' : 'Не удалось открыть карточку сервиса';
  String get chatByOrderNotFound => isEn ? 'Chat not found for this order' : 'Чат по заказу не найден';
  String get openChatFailed => isEn ? 'Could not open chat' : 'Не удалось открыть чат';

  // Вкладка «Поиск» (карта и список сервисов)
  String get searchScreenTitle => isEn ? 'Find a shop' : 'Поиск сервиса';
  String get searchFieldHint => isEn ? 'Name, address, or service' : 'Название, адрес или услуга';
  String get searchResetAll => isEn ? 'Clear all' : 'Сбросить всё';
  String get searchViewMap => isEn ? 'Map' : 'Карта';
  String get searchViewList => isEn ? 'List' : 'Список';
  String get searchNothingFound => isEn ? 'Nothing found' : 'Ничего не найдено';
  String get searchEmptyTryFilters =>
      isEn ? 'Try changing services or clear the filter' : 'Попробуйте изменить набор услуг или сбросить фильтр';
  String get searchEmptyCarFilterHint => isEn
      ? 'Tap “Show all” below or turn off “Sort by car” in Profile'
      : 'Нажмите «Показать все» ниже или отключите «Сортировать по машине» в профиле';
  String get searchEmptyChangeQuery =>
      isEn ? 'Change the category filter or search query' : 'Измените фильтр или поисковый запрос';
  String get searchClearFilter => isEn ? 'Clear filter' : 'Сбросить фильтр';
  String get searchEditServices => isEn ? 'Edit services' : 'Изменить набор услуг';
  String get searchHideAll => isEn ? 'Hide all' : 'Скрыть все';
  String get searchShowAll => isEn ? 'Show all' : 'Показать все';
  String get searchShareSoon => isEn ? 'Sharing will be available in a future update' : 'Поделиться — в следующей версии';
  String get searchMapNoCoordsHint => isEn
      ? 'Places without coordinates are hidden on the map. Open the List tab to see them.'
      : 'На карте не видно точек без координат. Во вкладке «Список» они отображаются.';
  String get searchOpenInGoogleMaps => isEn ? 'Open in Google Maps' : 'Открыть в Google Картах';
  String get searchOpenInYandexMaps => isEn ? 'Open in Yandex Maps' : 'Открыть в Яндекс.Картах';
  String get searchMyLocation => isEn ? 'My location' : 'Моё местоположение';
  String get searchHideNonPartners => isEn ? 'Hide non-partner places' : 'Скрыть непартнёрские';
  String get searchShowNonPartners => isEn ? 'Show non-partner places' : 'Отобразить непартнёрские';
  String get searchWithCarBrandFilter => isEn ? 'With car brand filter' : 'С фильтром по марке';
  String get searchWithoutCarBrandFilter => isEn ? 'Without car brand filter' : 'Без фильтра по марке';
  String get searchExternalNotPartner =>
      isEn ? 'This business is not a partner of MP-Servis' : 'Данная организация не сотрудничает с MP-Servis';
  String get searchClose => isEn ? 'Close' : 'Закрыть';
  String get searchNoPhone => isEn ? 'No phone number' : 'Нет номера для звонка';
  String get searchDialFailed => isEn ? 'Could not start the call' : 'Не удалось открыть набор номера';
  String get searchFiltersTitle => isEn ? 'Filters' : 'Фильтры';
  String get searchDistanceKm => isEn ? 'Distance (km)' : 'Расстояние (км)';
  String get searchMinRating => isEn ? 'Minimum rating' : 'Минимальный рейтинг';
  String get searchFiltersReset => isEn ? 'Reset' : 'Сбросить';
  String get searchFiltersApply => isEn ? 'Apply' : 'Применить';
  String get searchRatingAny => isEn ? 'Any' : 'Любой';
  String get searchServiceFilterTitle => isEn ? 'Filter by services' : 'Фильтр по услугам';
  String get searchServicesSearchHint => isEn ? 'Search services' : 'Поиск по услугам';
  String get searchCategoryOther => isEn ? 'Other' : 'Прочее';
  String get searchCategoryServicesFallback => isEn ? 'Services' : 'Услуги';
  String get searchOpen => isEn ? 'Open' : 'Открыто';
  String get searchClosed => isEn ? 'Closed' : 'Закрыто';
  String get searchShare => isEn ? 'Share' : 'Поделиться';
  String get searchCall => isEn ? 'Call' : 'Позвонить';
  String get searchRoute => isEn ? 'Directions' : 'Маршрут';
  String get searchSelectPhone => isEn ? 'Choose a phone number' : 'Выберите номер';

  /// Чипы категории (партнёрский API + фильтр внешних POI по русским меткам типов).
  String get searchFilterAll => isEn ? 'All' : 'Все';
  String get searchKindSto => isEn ? 'Auto shop' : 'Автосервис';
  String get searchKindSelfWash => isEn ? 'Self-service wash' : 'Самомойка';
  String get searchKindRobotWash => isEn ? 'Automatic wash' : 'Робомойка';
  String get searchKindCarWash => isEn ? 'Car wash' : 'Мойка';
  String get searchKindDetailing => isEn ? 'Detailing' : 'Детейлинг';
  String get searchKindTire => isEn ? 'Tire service' : 'Шиномонтаж';
  String get searchKindBody => isEn ? 'Body shop' : 'Кузовной';
  String get searchKindCarAudio => isEn ? 'Car audio' : 'Автозвук';
  String get searchKindOther => isEn ? 'Other' : 'Другое';

  /// Общий фильтр «Мойка»; подтипы (классика / самообслуживание / робот) — отдельные чипы.
  String get searchKindCarWashGroup => isEn ? 'Car wash' : 'Мойка';
  String get searchWashSubtypeClassic => isEn ? 'Classic' : 'Классическая';
  String get searchWashSubtypeSelfService => isEn ? 'Self-service' : 'Самообслуживание';
  String get searchWashSubtypeRobot => isEn ? 'Robotic' : 'Робот';

  String get searchListLoadError => isEn
      ? 'Could not load the list. Check your network and sign-in.'
      : 'Не удалось загрузить список. Проверьте сеть и вход в аккаунт.';
  String get searchEmptyAllServices => isEn
      ? 'No shop offers all selected services at once'
      : 'Ни одна организация не выполняет все выбранные услуги';
  String get searchEmptyCarBrand => isEn
      ? 'No shops match your vehicle brand filter'
      : 'Нет организаций под марку выбранного авто';
  String searchFoundOrganizations(int n) =>
      isEn ? 'Found: $n shops' : 'Найдено организаций: $n';
}
