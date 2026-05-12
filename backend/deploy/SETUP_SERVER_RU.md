# Первый вывод API и PostgreSQL на VPS (Ubuntu 24.04)

Пример сервера: **root@217.114.0.114** (замените IP при необходимости).  
SSH с вашего ПК:

```powershell
ssh -i $env:USERPROFILE\.ssh\id_ed25519_mp_servis_vps root@217.114.0.114
```

---

## 1. Базовая настройка

```bash
apt update && apt upgrade -y
timedatectl set-timezone Europe/Moscow
```

Создайте пользователя для приложения (без входа по паролю, только для сервиса):

```bash
useradd --system --home-dir /opt/mp-servis --shell /usr/sbin/nologin mpservis
mkdir -p /opt/mp-servis/api
chown -R mpservis:mpservis /opt/mp-servis
```

---

## 2. Node.js 20 LTS

```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs build-essential
node -v   # v20.x
```

---

## 3. PostgreSQL

```bash
apt install -y postgresql postgresql-contrib
systemctl enable --now postgresql
```

Создайте роль и базу (пароль замените на свой):

```bash
sudo -u postgres psql <<'SQL'
CREATE USER mp_servis_app WITH PASSWORD 'ЗАМЕНИТЕ_НА_СИЛЬНЫЙ_ПАРОЛЬ';
CREATE DATABASE mp_servis OWNER mp_servis_app;
GRANT ALL PRIVILEGES ON DATABASE mp_servis TO mp_servis_app;
\c mp_servis
GRANT ALL ON SCHEMA public TO mp_servis_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO mp_servis_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO mp_servis_app;
SQL
```

Проверка:

```bash
sudo -u postgres psql -c "\l" | grep mp_servis
```

---

## 4. Код API на сервере

**Вариант A — git (рекомендуется):**

```bash
apt install -y git
# Если репозиторий приватный — настройте deploy key или используйте HTTPS + token
sudo -u mpservis git clone https://github.com/ВАШ/MP.git /opt/mp-servis/repo
```

Тогда приложение можно держать так: рабочая копия только для деплоя:

```bash
rsync -a --delete /opt/mp-servis/repo/backend/ /opt/mp-servis/api-tmp/
# или: копировать только backend без node_modules
```

Проще для старта — **клонировать только `backend`** в `/opt/mp-servis/api` или собрать локально и залить `scp -r`.

**Вариант B — с вашего ПК (Windows), из папки `backend`:**

```powershell
# В PowerShell на ПК (установите OpenSSH Client при необходимости)
scp -i $env:USERPROFILE\.ssh\id_ed25519_mp_servis_vps -r C:\dev\MP\backend\* root@217.114.0.114:/opt/mp-servis/api/
```

На сервере владелец:

```bash
chown -R mpservis:mpservis /opt/mp-servis/api
```

---

## 5. Переменные окружения и сборка

```bash
cd /opt/mp-servis/api
sudo -u mpservis cp deploy/.env.production.example .env
sudo -u mpservis nano .env
chmod 600 .env
```

В `.env` обязательно: `DATABASE_URL`, `JWT_SECRET`, `API_BASE_URL`, почта/OTP для прода.

```bash
cd /opt/mp-servis/api
# Нужен полный npm ci (есть @nestjs/cli). На **пустой** БД — только первый раз:
sudo -u mpservis npm ci
sudo -u mpservis env DB_BOOTSTRAP_RESET=1 npm run db:bootstrap
sudo -u mpservis npm run build
sudo -u mpservis npm run migration:run:prod
sudo -u mpservis npm prune --omit=dev
```

Каталог загрузок:

```bash
sudo -u mpservis mkdir -p /opt/mp-servis/api/uploads
```

---

## 6. systemd

```bash
cp /opt/mp-servis/api/deploy/systemd/mp-servis-api.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now mp-servis-api
systemctl status mp-servis-api
journalctl -u mp-servis-api -f
```

Проверка локально на сервере:

```bash
curl -sS http://127.0.0.1:3000/api/v1/reference/car-brands | head -c 200
```
(или любой публичный GET из вашего API)

---

## 7. nginx + HTTPS

```bash
apt install -y nginx
cp /opt/mp-servis/api/deploy/nginx/mp-servis-api.conf.example /etc/nginx/sites-available/mp-servis-api
nano /etc/nginx/sites-available/mp-servis-api
ln -s /etc/nginx/sites-available/mp-servis-api /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
```

**Домен:** A-запись поддомена `api` → `217.114.0.114`.

```bash
apt install -y certbot python3-certbot-nginx
certbot --nginx -d api.ВАШ-ДОМЕН.ru
```

После certbot в конфиге появятся `ssl_certificate`. В `.env` укажите `API_BASE_URL=https://api.ВАШ-ДОМЕН.ru/api/v1` и перезапустите сервис:

```bash
systemctl restart mp-servis-api
```

---

## 8. Файрвол

```bash
apt install -y ufw
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw enable
ufw status
```

Порт **3000 снаружи не открывайте** — только nginx 80/443.

---

## Обновление после правок в коде

### Важно: каталог `uploads/` (обязательно сохранять)

Файлы, которые отдаются по URL из БД (фото заказов, аватары пользователей, фото организаций, фото авто в гараже и т.д.), лежат **на диске**, не в PostgreSQL. Пути вроде `uploads/order-photos/...`, `uploads/client-cars/...` считаются от **`process.cwd()`** — на VPS это **`/opt/mp-servis/api/uploads/`**.

При **полной замене** каталога `/opt/mp-servis/api` (копирование архива, `scp -r` без слияния, `mv api api.bak && распаковка новой`) папка **`uploads` из новой сборки пустая или отсутствует**, а старые файлы остаются только в **бэкапе** (`api.bak.*`). В БД записи целы, но картинки «пропадают» в приложении.

**Перед или сразу после выкладки нового кода** нужно **перенести загрузки** со старого дерева в новое:

```bash
# Пример: предыдущая копия после бэкапа
OLD=/opt/mp-servis/api.bak.XXXXXXXX
NEW=/opt/mp-servis/api
mkdir -p "$NEW/uploads"
rsync -a "$OLD/uploads/" "$NEW/uploads/"
chown -R mpservis:mpservis "$NEW/uploads"
```

То же правило, если деплой идёт **с вашего ПК** в пустой каталог на сервере: **не затирайте** существующий `uploads` без копирования из бэкапа.

Отдельно всегда сохраняйте **`/opt/mp-servis/api/.env`** (секреты и `DATABASE_URL`).

---

### Обновление «на месте» (git pull в том же каталоге)

Если код обновляется **внутри** уже существующего `/opt/mp-servis/api` и каталог **не удаляется целиком**, `uploads/` обычно **остаётся на месте** — дополнительных действий не требуется.

На сервере от пользователя с доступом к `/opt/mp-servis/api`:

```bash
cd /opt/mp-servis/api
sudo -u mpservis git pull   # если деплой через git
sudo -u mpservis npm ci
sudo -u mpservis npm run build
sudo -u mpservis npm run migration:run:prod
sudo -u mpservis npm prune --omit=dev
sudo systemctl restart mp-servis-api
```

**Не** запускайте `DB_BOOTSTRAP_RESET=1` при обновлении на боевой БД — это сотрёт данные.

---

## Подключение API к БД от `mp_servis_app` (не от `postgres`)

Рекомендуется: приложение подключается ролью **`mp_servis_app`** к базе **`mp_servis`**, а не суперпользователем `postgres`.

После первичной настройки PostgreSQL (раздел 3) выполните на **VPS от root** скрипт из репозитория:

```bash
scp deploy/switch_to_app_db_user.sh root@ВАШ_IP:/tmp/
ssh root@ВАШ_IP 'chmod +x /tmp/switch_to_app_db_user.sh && bash /tmp/switch_to_app_db_user.sh'
```

Скрипт: задаёт новый пароль для `mp_servis_app`, выдаёт права на схему `public`, записывает `DATABASE_URL=postgresql://mp_servis_app:…@localhost:5432/mp_servis` в `/opt/mp-servis/api/.env` (резервная копия `.env.bak_before_mp_servis_app`), запускает миграции и перезапускает `mp-servis-api`.

---

## Чеклист мобильных приложений

- Сборка с `--dart-define=MP_SERVIS_API_HOST=api.ВАШ-ДОМЕН.ru` **не подойдёт**, если за nginx только 443 без порта — нужен полный HTTPS URL в коде (см. план: `MP_SERVIS_API_BASE_URL` или хост + схема https без порта 3000).

Сейчас в `AppConfig` задано `http://$host:$port` — для продакшена добавьте отдельные define или правку под `https` и порт 443 (без `:3000` в URL).
