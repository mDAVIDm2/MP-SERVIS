# План бэкенда и БД для AutoHub (Client + Business)

Документ описывает единый бэкенд и схему БД для связки **AutoHub Client** (клиенты) и **AutoHub Business** (СТО/мастера). Реализацию БД и API планируется выполнить после стабилизации приложений.

---

## Цель

- Один бэкенд: NestJS (или аналог), PostgreSQL, Redis, S3, WebSocket.
- Одинаковые сущности и статусы в Client и Business (один источник правды).
- Изоляция по `organization_id`: СТО видит только свои заказы, клиентов, сотрудников.

---

## Рекомендуемый стек

| Компонент   | Технология   | Назначение                          |
|------------|---------------|-------------------------------------|
| API        | NestJS        | REST + WebSocket, JWT, роли         |
| БД         | PostgreSQL    | Основные данные                     |
| Кэш/очереди| Redis         | Сессии, очереди, real-time          |
| Файлы      | S3-совместимое| Фото заказов, аватары, логотипы     |
| Реальное время | WebSocket  | Уведомления, чаты, смена статусов   |

---

## Ключевые сущности (совместимо с клиентом)

- **users** — клиенты и сотрудники СТО (роль: client / owner / admin / master / solo).
- **organizations** — СТО (название, адрес, телефон, часы работы, логотип).
- **organization_members** — связь user ↔ organization с ролью (owner, admin, master).
- **cars** — автомобили клиентов (привязка к user).
- **orders** — заказы (client_id, organization_id, car_id, status, date_time, master_id и т.д.).
- **order_items** — позиции заказа (услуга, цена, длительность, is_additional, is_approved).
- **chats** — чаты по заказу (order_id).
- **messages** — сообщения в чате.
- **reviews** — отзывы о СТО.
- **notifications** — уведомления (push, in-app).

Статусы заказа (единые для Client и Business):

- PENDING_CONFIRMATION → CONFIRMED → IN_PROGRESS → PENDING_APPROVAL → IN_PROGRESS → COMPLETED → DONE  
- CANCELLED — в любой момент.

---

## API (кратко)

- **Auth**: POST `/auth/send-code`, `/auth/verify-code`, `/auth/refresh`, `/auth/logout`.
- **Profile**: GET/PATCH `/profile` (для Business — роль и organization_id в JWT).
- **Orders**: GET `/orders` (scoped по organization_id для Business), GET/PATCH `/orders/:id`, PATCH `/orders/:id/status`, POST `/orders/:id/assign-master`.
- **Catalog**: поиск СТО, услуги, отзывы, слоты (для Client).
- **Organizations**: GET/PATCH `/organizations/:id`, staff, services (для Business).
- **Chats**: GET `/chats`, GET/POST `/chats/:id/messages`.
- **Notifications**: GET `/notifications`, регистрация push-токена.

Для роли **Master** API не возвращает цены в позициях заказа и телефоны клиентов.

---

## Изоляция и безопасность

- JWT содержит `userId`, `role`, `organizationId` (для Business).
- Все запросы Business к заказам/чатам/клиентам фильтруются по `organization_id`.
- Клиент видит только свои заказы, машины, чаты.

---

## Репозиторий (рекомендуемая структура)

```
autohub_backend/     — NestJS, модули: auth, users, organizations, orders, chats, catalog, notifications
autohub_shared/      — общие DTO, enum (OrderStatus и т.д.) — опционально пакет Dart + TS
autohub_client2/     — клиентское приложение (готово)
autohub_business/    — приложение для СТО (Android, Web, Desktop)
```

---

## Следующие шаги

1. Инициализировать бэкенд (NestJS), подключить PostgreSQL и Redis.
2. Реализовать модули Auth, Users, Organizations, Orders (CRUD + state machine).
3. Реализовать Chats и Notifications (WebSocket).
4. Подключить Client и Business к одному API (заменить моки на реальные вызовы).
5. При необходимости вынести общие модели в пакет `autohub_shared`.
