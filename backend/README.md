# AutoHub Backend (NestJS + PostgreSQL)

API для приложений **AutoHub Business** и **AutoHub Client**. Порт по умолчанию: 3000, префикс: `/api/v1`.

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
createdb autohub
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

API: http://localhost:3000/api/v1

## Эндпоинты (для Business-приложения)

- **Auth:** `POST /auth/send-code`, `POST /auth/verify-code`
- **Profile:** `GET /profile` (JWT)
- **Organizations:** `GET/PATCH /organizations/:id`, `GET/POST/PATCH /organizations/:id/staff`, `GET/PATCH /organizations/:id/settings`
- **Orders:** `GET/POST /orders`, `GET/PATCH /orders/:id`, `PATCH /orders/:id/status`, `POST /orders/:id/assign-master`, `POST /orders/:id/cancel`, `PATCH /orders/:id/items`
- **Chats:** `GET /chats`, `GET/POST /chats/:id/messages`
- **Notifications:** `GET /notifications`, `POST /notifications/register-device`

## Подключение Business-приложения

В `autohub_business` в `lib/core/api/api_endpoints.dart` уже указано:

- `baseUrl = 'http://localhost:3000/api/v1'`
- `wsUrl = 'ws://localhost:3000/ws'` (WebSocket — при необходимости добавьте gateway)

Запустите бэкенд и приложение Business — авторизация и данные пойдут в PostgreSQL.
