# MP-Servis Backend (NestJS + PostgreSQL)

API для приложений **MP-Servis Business** и клиента **MP-Servis**. Порт по умолчанию в коде и в `.env.example`: **3001** (если в `.env` не задан `PORT`); префикс: `/api/v1`.

## Требования

- Node.js 18+
- PostgreSQL 14+

## Установка

```bash
npm install
cp .env.example .env
# Отредактируйте .env: DATABASE_URL, JWT_SECRET
```

## База данных

Создайте БД:

```bash
createdb mp_servis
```

При первом запуске TypeORM создаст таблицы (`synchronize: true` в dev). В production используйте миграции.

## Запуск

```bash
# Разработка
npm run start:dev

# Production
npm run build
npm run start
```

API: `http://localhost:3001/api/v1` (или ваш `PORT` из `.env`).

## Эндпоинты (для Business-приложения)

- **Auth:** `POST /auth/send-code`, `POST /auth/verify-code`
- **Profile:** `GET /profile` (JWT)
- **Organizations:** `GET/PATCH /organizations/:id`, `GET/POST/PATCH /organizations/:id/staff`, `GET/PATCH /organizations/:id/settings`
- **Orders:** `GET/POST /orders`, `GET/PATCH /orders/:id`, `PATCH /orders/:id/status`, `POST /orders/:id/assign-master`, `POST /orders/:id/cancel`, `PATCH /orders/:id/items`
- **Chats:** `GET /chats`, `GET/POST /chats/:id/messages`
- **Notifications:** `GET /notifications`, `POST /notifications/register-device`

## Подключение приложений Flutter

Базовый URL задаётся в **`AppConfig`** (`autohub_business` / `autohub_client2`): `--dart-define=MP_SERVIS_API_HOST=...` и при необходимости `--dart-define=MP_SERVIS_API_PORT=3001`, либо полный `--dart-define=MP_SERVIS_API_BASE_URL=http://.../api/v1`.

## Деплой на VPS (Ubuntu)

Шаблоны **systemd**, **nginx**, пример `.env` для прода и пошаговая инструкция:

- [`deploy/SETUP_SERVER_RU.md`](deploy/SETUP_SERVER_RU.md) — Ubuntu VPS.
- [`deploy/SETUP_WINDOWS_LAN_SERVER_RU.md`](deploy/SETUP_WINDOWS_LAN_SERVER_RU.md) — **Windows в LAN** (обновление через Git, порт **3001**, IP **192.168.1.145**). Скрипт «всё сразу»: [`deploy/update_and_run_backend_windows_lan.ps1`](deploy/update_and_run_backend_windows_lan.ps1).

В `SETUP_SERVER_RU.md` есть раздел **«Важно: каталог uploads/»**: при полной замене каталога API на сервере нужно **сохранить или слить** `uploads/` (фото пользователей и организаций не в БД, а на диске).

Миграции на сервере без dev-зависимостей: `npm run build` затем `npm run migration:run:prod`.
