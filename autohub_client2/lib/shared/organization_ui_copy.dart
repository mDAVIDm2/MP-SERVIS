/// Нейтральные подписи для поиска и карточек (не только автосервис).
class OrganizationUiCopy {
  OrganizationUiCopy._();

  static String listLoadError() =>
      'Не удалось загрузить список. Проверьте сеть и вход в аккаунт.';

  static String emptyAllServicesSelected() =>
      'Ни одна организация не выполняет все выбранные услуги';

  static String emptyCarBrandHidden() =>
      'Нет организаций под марку выбранного авто';

  static String foundOrganizations(int n) => 'Найдено организаций: $n';

  static String showAllOrganizations() => 'Показать все';

  static String ordersTooltip(String kindLabel) => 'Заказы: $kindLabel';

  static String schedulingStaffSubtitle() => 'Запись к специалисту';

  static String schedulingBaySubtitle() => 'Запись на свободное окно';

  static String approvalEmptySlotsHint() =>
      'Можно подтвердить дату — точное время согласует организация.';

  static String approvalConfirmDate() =>
      'Подтвердить дату (время уточнит организация)';
}
