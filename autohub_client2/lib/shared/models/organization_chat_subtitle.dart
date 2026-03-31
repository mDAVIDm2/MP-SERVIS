/// Подпись под названием организации в чате (клиентское приложение).
/// Коды совпадают с `business_kind` / `organization_kind` в API списка чатов (одинаковые значения).
String chatSubtitleForOrganizationKind(String? kindCode) {
  switch (_normalize(kindCode)) {
    case 'car_wash':
      return 'Чат с мойкой';
    case 'detailing':
      return 'Чат с детейлингом';
    case 'car_audio':
      return 'Чат с автозвуком';
    case 'tire_service':
      return 'Чат с шиномонтажом';
    case 'body_shop':
      return 'Чат с кузовным сервисом';
    case 'glass':
      return 'Чат с автостёклами';
    case 'tuning':
      return 'Чат с тюнинг-ателье';
    case 'ev_service':
      return 'Чат с сервисом электромобилей';
    case 'other':
      return 'Чат с сервисом';
    case 'sto':
      return 'Чат с автосервисом';
    default:
      return 'Чат с сервисом';
  }
}

String _normalize(String? raw) {
  return (raw ?? 'sto').trim().toLowerCase().replaceAll('-', '_');
}
