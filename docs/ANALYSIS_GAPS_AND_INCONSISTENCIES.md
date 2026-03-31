# Анализ проекта AutoHub: несостыковки, заглушки и недоработки

Полный обход структуры проекта (backend NestJS, autohub_business, autohub_client2), API и кода. Дата анализа: март 2025.

---

## 1. Заглушки и заглушко-подобный код

### 1.1 Репозитории со StubPrefs (Business)

При отсутствии `SharedPreferences` (ещё не инициализированы) репозитории создаются с **заглушкой** `_StubPrefs`, реализующей пустой `SharedPreferences`:

| Файл | Строка |
|------|--------|
| `organization_repository.dart` | 111, 130 |
| `staff_repository.dart` | 162, 166 |
| `settings_repository.dart` | 292, 295 |
| `client_notes_repository.dart` | 53, 57 |

**Риск:** до загрузки prefs все операции «сохранения» ничего не делают; кэш не пишется. После появления prefs репозиторий пересоздаётся (через `ref.watch`), но возможны гонки при быстром переключении orgId.

### 1.2 Client: MockSTORepository и ApiSTORepository

- **MockSTORepository** — явная заглушка (пустые списки, `getSTOById` → notFound). В проде **не используется**: в `app_providers.dart` подключён `ApiSTORepository`.
- **ApiSTORepository**:
  - `getFavorites()` — всегда `Result.success([])` (без вызова API).
  - `getReviews(stoId)` — всегда `Result.success([])` (без вызова API).
  - `toggleFavorite(stoId)` — всегда `Result.success(null)` (ничего не меняет).

На бэкенде нет эндпоинтов: `/catalog/favorites`, `/catalog/organizations/:id/reviews`. Избранное и отзывы по сути заглушки на клиенте.

### 1.3 Client: экран записи (booking_screen) — **ИСПРАВЛЕНО**

~~Первые два слота в списке времени принудительно недоступны («демо»).~~ Искусственное отключение первых двух слотов удалено; слоты отображаются строго по данным с бэкенда.

### 1.4 Client: напоминания ТО (maintenance_reminders_provider)

```dart
// TODO: при подключении БД заменить на ref.watch(maintenanceServicesRepositoryProvider).getTypes();
```

Типы работ для напоминаний пока не с API/БД — захардкоженный или локальный источник.

### 1.5 Client: отзыв по заказу

В `ApiOrderRepository.addReview()` возвращается заглушка-ошибка:

```dart
return Result.failure(const ApiException(
  code: ApiErrorCode.internal,
  message: 'Отзыв через API пока не реализован',
));
```

Эндпоинт `POST /orders/:id/review` в бэкенде отсутствует.

---

## 2. Время и часовые пояса

### 2.1 Единообразие: UTC на границе API

- **Бэкенд:** все поля времени в БД — `timestamptz`; в JSON отдаётся ISO 8601 (UTC): `date_time`, `planned_start_time`, `planned_end_time`, `created_at`, `updated_at`, `proposed_date_time` в чатах.
- **Business:** при отправке `proposed_date_time` и `date_time` используется `toUtc().toIso8601String()` — корректно.
- **Client:** при создании заказа и при подтверждении с `date_time` тоже отправляется UTC — корректно.
- **Client, слоты:** сервер отдаёт `start` в ISO (UTC); в `api_sto_repository.dart` время переводится в локальное (`dt.toLocal()`) и в сетку отдаётся `"HH:mm"` — корректно (в т.ч. по `DIAGNOSTIC_AVAILABLE_SLOTS.md`).

### 2.2 Дата «дня» для слотов на бэкенде — **ИСПРАВЛЕНО**

Парсинг даты для слотов переведён на **строгий UTC**: `Date.UTC(y, m, d, ...)` по компонентам `YYYY-MM-DD`, границы дня и расчёт слотов (workStart/workEnd) считаются в UTC. Сдвиг суток при разных часовых поясах сервера и клиента устранён.

### 2.3 Парсинг дат в Order (Business) — **ИСПРАВЛЕНО**

В `order_model.dart` поле `dateTime` сделано **nullable** (`DateTime?`). `_parseDateTime` при `null` или невалидной строке возвращает `null` (текущее время больше не подставляется). Для сортировки и сравнения используется геттер `effectiveDateTime`; для отображения — `formatDateTimeOrNull` / `formatTimeOrNull` / `formatDateOrNull` (показ «—» при null). Аналогично в `OrderPhoto`: `createdAt` nullable, `_parseAt` возвращает `null`.

---

## 3. Несоответствия API (клиент объявил — бэкенд не реализовал)

В `autohub_client2` в `api_endpoints.dart` объявлены эндпоинты, которых **нет** в текущем бэкенде:

| Эндпоинт (Client) | Использование | Бэкенд |
|-------------------|---------------|--------|
| `POST /notifications/:id/read` | `NotificationApiService.markAsRead(id)` | **Реализовано** (заглушка без таблицы уведомлений) |
| `GET /catalog/favorites` | Не вызывается (ApiSTORepository возвращает []) | Нет |
| `GET /catalog/organizations/:id/reviews` | Не вызывается (возвращает []) | Нет |
| `GET /catalog/organizations/:id/availability` | Не найден в коде | Нет |
| `GET/POST /bookings`, `GET /bookings/:id` | Не найдены в коде | Нет |
| `POST /orders/:id/review` | addReview → заглушка «не реализован» | Нет |
| `GET /profile/avatar`, `GET/DELETE /profile/delete` | Не найдены в коде | Нет (есть только GET /profile) |
| `POST /chats/:chatId/messages/:msgId/read` | Не найден в коде | Нет |
| `/reference/car-brands`, `/reference/cities`, `/reference/service-categories` | Не найдены в коде | Нет |

Итог: эндпоинт `POST /notifications/:id/read` добавлен на бэкенд (заглушка). Остальные перечисленные маршруты либо не вызываются, либо обрабатываются заглушкой на клиенте.

---

## 4. Логика согласования доп. работ (approval)

### 4.1 Бэкенд: фильтрация по approvedItemIds — **ИСПРАВЛЕНО**

В `orders.service.ts`, `approveByClient`: при одобрении в заказ добавляются **только** те элементы из `approval_items`, чей ID (или индекс как `String(index)`) входит в массив `approvedItemIds`. Для обратной совместимости: если клиент присылает ровно `['0']` и пунктов в сообщении больше одного, добавляются все пункты (legacy-маркер «одобрено»).

### 4.2 Документация GAPS vs фактическое поведение — **УТОЧНЕНО**

Ответ клиента по согласованию **уходит на бэкенд**: Client вызывает `approveItems` (POST `/orders/:id/approval`) и `confirmOrder` (POST `/orders/:id/confirm`). В GAPS убрана неактуальная формулировка про «(демо)» и «ответ не уходит на бэкенд».

---

## 5. Прочие недоработки (уже отражённые в GAPS/IMPLEMENTATION_STATUS)

Кратко, без дублирования деталей из `GAPS_AND_SIMPLIFICATIONS.md` и `IMPLEMENTATION_STATUS.md`:

- **Оплата** — нет экранов и привязки к заказу.
- **Push-уведомления** — регистрация устройства есть на бэкенде; в Business эндпоинты уведомлений не используются.
- **Refresh token** — не реализован (есть только в ApiEndpoints).
- **GET /profile при старте** — не вызывается для актуализации роли/организации после входа.
- **Аналитика** — только «сегодня», без выбора периода и среднего чека.
- **Детальные маршруты** (например `/app/orders/:id`) — переходы через `Navigator.push`, не через go_router.
- **Клиенты СТО** — только агрегация по заказам, отдельного API «клиенты организации» нет.
- **Календарь** — слоты и привязка заказов к мастерам/времени упрощены (нет сетки слотов и перетаскивания).

---

## 6. Сводная таблица по категориям

| Категория | Что найдено | Статус |
|-----------|-------------|--------|
| **Заглушки** | StubPrefs в 4 репозиториях Business; getFavorites/getReviews/toggleFavorite в Client (стабы); addReview; TODO по типам напоминаний. | Первые 2 слота (демо) — исправлено. |
| **Время** | UTC на API соблюдён. | Парсинг слотов переведён на UTC; парсинг дат заказа — nullable, без fallback. |
| **API** | Ряд эндпоинтов в Client объявлен, но не реализован на бэкенде. | `POST /notifications/:id/read` добавлен. |
| **Логика** | approveByClient фильтрует по approvedItemIds. | Исправлено; GAPS уточнён. |

---

## 7. Рекомендации по приоритетам

1. **Высокий приоритет**  
   - Убрать или изменить fallback `DateTime.now()` в `Order._parseDateTime` (и аналоги в `OrderPhoto._parseAt`), чтобы не подставлять «сейчас» при битых данных.  
   - В `approveByClient` учитывать `approvedItemIds` (и при необходимости `rejectedItemIds`) при формировании списка добавляемых позиций из `approval_items`.  
   - Либо реализовать `POST /notifications/:id/read`, либо не вызывать `markAsRead` до появления эндпоинта (или обрабатывать 404).

2. **Средний приоритет**  
   - Зафиксировать и при необходимости описать в коде/документации интерпретацию даты слотов (зона сервера/организации).  
   - Убрать жёсткое «первые два слота недоступны» в booking_screen или заменить на реальную проверку по слоту с API.  
   - Обновить GAPS_AND_SIMPLIFICATIONS.md в части согласования и «демо».

3. **Низкий приоритет**  
   - Реализовать избранное и отзывы (каталог) при появлении продуктивной необходимости.  
   - Привести api_endpoints в Client в соответствие с реально существующими маршрутами (удалить или пометить «не реализовано»).

Документ можно дополнять по мере исправлений и появления новых эндпоинтов.
