/// Индексы вкладок главного меню на desktop после добавления «Склад».
///
/// Порядок для [BusinessRole.owner]: Панель, Расписание, Заказы, Автомобили,
/// Склад, Клиенты, Чаты, Финансы, Настройки. У владельца вкладка «Клиенты»
/// всегда присутствует (`canSeeClients` для owner — true).
abstract final class BusinessDesktopOwnerNav {
  static const int panel = 0;
  static const int schedule = 1;
  static const int orders = 2;
  static const int cars = 3;
  static const int inventory = 4;
  static const int clients = 5;
  static const int chats = 6;
  static const int finance = 7;
  static const int settings = 8;
}
