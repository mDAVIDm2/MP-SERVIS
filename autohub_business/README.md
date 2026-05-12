# MP-Servis Business

Приложение для СТО и частных мастеров — часть экосистемы MP-Servis. Работает с тем же бэкендом, что и клиентское приложение MP-Servis (клиент).

## Платформы

- **Android** — основная платформа (нижняя панель навигации).
- **Web** — `flutter build web` (на широком экране — боковое меню).
- **Windows / macOS** — `flutter build windows` / `flutter build macos`.

## Роли

- **Owner** — владелец; дашборд, аналитика, персонал, настройки.
- **Admin** — заказы, календарь, чаты, клиенты, назначение мастера.
- **Master** — только «Мои задачи» и «Профиль»; без цен и телефонов клиентов.
- **Solo** — самозанятый; объединённый режим без раздела «Персонал».

## Запуск

```bash
# Зависимости
flutter pub get

# Android
flutter run

# Web
flutter run -d chrome

# Windows
flutter run -d windows
```

## Структура

- `lib/core/` — API, auth (с ролями), тема (#FF6B00), утилиты.
- `lib/features/` — auth, dashboard, orders, calendar, chats, master_tasks, profile.
- `lib/shared/` — модели (Order, OrderStatus), main_shell (навигация по ролям).
- `docs/` — промпты и [план бэкенда/БД](docs/BACKEND_AND_DB_PLAN.md).

## Демо-вход

| Код  | Роль            | Навигация |
|------|-----------------|-----------|
| 1111 | Мастер          | Мои задачи, Профиль |
| 2222 | Владелец        | Главная, Календарь, Заказы, Чаты, Профиль |
| 3333 | Самозанятый     | Заказы, Календарь, Чаты, Профиль (без Персонала) |
| иной | Администратор   | Заказы, Календарь, Чаты, Профиль |

Тестовые **email** (`owner@mpservis.test` и т.д.) и **телефоны** из бэкенда (`auth.service`) работают только если в **`backend/.env`** на машине с API задано `ALLOW_TEST_AUTH=1` и **`NODE_ENV` не `production`**. Отдельно для Control Center в том же `.env` нужен **`INTERNAL_JWT_SECRET`** (см. `backend/.env.example`).

После появления бэкенда — заменить на вызовы API и роль из JWT. Полный статус реализации — в [docs/IMPLEMENTATION_STATUS.md](docs/IMPLEMENTATION_STATUS.md).

## Дальнейшие шаги

1. Подключить реальный API (см. `docs/BACKEND_AND_DB_PLAN.md`).
2. Push-уведомления и WebSocket для обновлений в реальном времени.
