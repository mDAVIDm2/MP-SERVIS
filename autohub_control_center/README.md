# MP-Servis Control Center

Панель для разработчиков/операторов: внутренние API (`/api/v1/internal/...`), справочники, организации, заказы, чаты поддержки.

## Подключение к серверу

По умолчанию приложение ходит на **продакшен** `https://api.mp-servis.ru/api/v1` (см. `lib/core/config/app_config.dart`).

Локальный Nest:

```bash
flutter run -d windows --dart-define=MP_SERVIS_API_BASE_URL=http://127.0.0.1:3000
```

## Запуск на Windows

Из корня монорепозитория:

```bat
run_control_center.bat
```

Опционально рядом с `run_control_center.bat` создайте **`control_center.credentials.dat`** (файл в `.gitignore` репозитория, не коммитьте):

- Скопируйте `control_center.credentials.example.dat` → `control_center.credentials.dat`
- Укажите `EMAIL=` и `PASSWORD=` — поля на экране входа подставятся автоматически (вход по кнопке «Войти»).

Переопределение API без правки кода:

```bat
set MP_SERVIS_API_BASE=http://127.0.0.1:3000
run_control_center.bat
```

## Учётная запись входа (важно)

Это **не** логин клиентского приложения MP-Servis. Вход идёт в таблицу **`internal_operators`** на сервере (`POST /api/v1/internal/auth/login`).

Если видите «Неверный email или пароль»:

1. На **сервере API** в `.env` должны быть заданы **`INITIAL_SUPERADMIN_EMAIL`** и **`INITIAL_SUPERADMIN_PASSWORD`**, затем **перезапуск** процесса Nest — при старте сработает сидер и создаст/обновит оператора.
2. Либо на машине с доступом к **той же БД**, что и прод, из папки `backend`:

   ```bash
   # в .env: INITIAL_SUPERADMIN_EMAIL=... и INITIAL_SUPERADMIN_PASSWORD=...
   npm run seed:internal
   ```

   Скрипт `scripts/seed-internal-admin.js` создаёт или обновляет пароль для указанного email.

Пароль в Control Center должен **совпадать** с тем, что записан в `internal_operators` (через env при старте или через `seed:internal`).
