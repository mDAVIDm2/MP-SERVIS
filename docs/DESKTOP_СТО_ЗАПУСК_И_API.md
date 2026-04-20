# Запуск десктопного приложения СТО и подключение к API

## Сборка и запуск под Windows

Из корня репозитория:

```bash
cd autohub_business
flutter pub get
flutter run -d windows
```

Или собрать exe:

```bash
flutter build windows
# Результат: build/windows/x64/runner/Release/
```

## Подключение к бэкенду (API)

По умолчанию приложение обращается к хосту из `AppConfig.apiHost` (см. `lib/core/config/app_config.dart`). Для локальной разработки, когда бэкенд и приложение на одном компьютере, задайте хост `localhost`:

```bash
flutter run -d windows --dart-define=MP_SERVIS_API_HOST=localhost
```

Или для сборки:

```bash
flutter build windows --dart-define=MP_SERVIS_API_HOST=localhost
```

Если бэкенд на другой машине в сети, укажите её IP:

```bash
flutter run -d windows --dart-define=MP_SERVIS_API_HOST=192.168.1.187
```

- **API:** `http://<apiHost>:3000/api/v1`
- **WebSocket (опционально):** `ws://<apiHost>:3000/ws`  
  Включить: `--dart-define=MP_SERVIS_ENABLE_WS=true`

## Порядок запуска для проверки связки

1. Запустить PostgreSQL и бэкенд (см. `LOCAL_DEV_AND_TESTING.md`).
2. Запустить десктопное приложение с нужным хостом:
   ```bash
   cd autohub_business
   flutter run -d windows --dart-define=MP_SERVIS_API_HOST=localhost
   ```
3. Войти по демо-коду (например `2222` — владелец, `1111` — мастер).

## Отличия desktop-интерфейса

- **Светлая тема** и боковая панель: Панель, Расписание, Заказы, Клиенты, Чаты, Персонал, Финансы, Настройки.
- **Верхняя шапка:** название раздела, поиск, чаты, уведомления.
- **Расписание:** по клику на заказ справа открывается инспектор-панель с деталями заказа (без перехода на отдельный экран).
- Тот же API и те же роли, что и в мобильном приложении.
