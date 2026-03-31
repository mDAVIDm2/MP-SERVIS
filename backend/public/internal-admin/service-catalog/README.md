# Админка: заявки в справочник услуг

Откройте в браузере (при запущенном API):

**http://localhost:3000/internal-admin/service-catalog/**

Вход — учётная запись **internal operator** (тот же JWT, что и для `POST /api/v1/internal/auth/login`).

## API (для интеграций)

- `GET /api/v1/internal/service-catalog/suggestions/stats` — счётчики
- `GET /api/v1/internal/service-catalog/suggestions?status=pending|reviewed|all&q=&page=&limit=`
- `PATCH /api/v1/internal/service-catalog/suggestions/:id` — тело: `{ "status": "pending"|"reviewed", "review_note": "..." }`

Все запросы с заголовком `Authorization: Bearer <internal_token>`.
