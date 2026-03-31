# Диагностика available-slots (28.02, только 12:00 и 14:00)

## Тестовый запрос (Postman / curl)

Эндпоинт требует JWT. После входа возьмите токен и выполните:

```bash
curl -X POST http://localhost:3000/api/v1/booking/available-slots \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{"organization_id":"ID_ОРГАНИЗАЦИИ","date":"2026-02-28","service_ids":["s1"]}'
```

Либо для **пятницы** (28.02.2025 — день недели 5, мастера в сиде работают Пн–Пт):

```bash
curl -X POST http://localhost:3000/api/v1/booking/available-slots \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{"organization_id":"ID_ОРГАНИЗАЦИИ","date":"2025-02-28","service_ids":["s1"]}'
```

## Что смотреть в консоли сервера

После запроса в логе должны появиться строки:

- `[available-slots] date= ... dayOfWeek= ... (0=Вс, 5=Пт, 6=Сб)` — для 2026-02-28 ожидается **6** (суббота); для 2025-02-28 — **5** (пятница).
- `requiredSkills=` — какие навыки запрошены.
- `mastersWithSchedule=` — сколько мастеров имеют график на этот день. Для **субботы** при сиде только Пн–Пт будет **0** → слотов не будет.
- `ordersOnThisDate=` — заказы, попадающие на эту дату; если их много, они «выжигают» окна и остаются только дырки (например 12:00 и 14:00).
- `slots.count=` и `first starts (ISO)=` — сколько слотов отдаётся и первые 20 значений `start` в ISO (UTC).

## Формат на клиенте (Flutter)

- Сервер отдаёт `start` в ISO (UTC), например `2026-02-28T09:00:00.000Z`.
- В `api_sto_repository.dart` время переводится в **локальное** (`dt.toLocal()`), затем извлекаются `hour` и `minute` в формате `"HH:mm"`.
- Сетка на экране: `allSlotsInDay()` → `"09:00"`, `"09:30"`, … `"17:30"`. Ячейка доступна, только если эта строка есть в `startTimes` из API (`isAvailable = available.contains(slot)`).

Если сервер присылает много слотов, а клиент всё равно показывает только 12:00 и 14:00 — до исправления парсинга причиной был учёт UTC вместо локального времени (например, 09:00 по Москве = 06:00 UTC → в списке было "06:00", которого нет в сетке 09:00–17:30).
