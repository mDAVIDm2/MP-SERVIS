# Дамп PostgreSQL с VPS и восстановление на Windows (Docker)

Полный цикл: **снять дамп на старом сервере** → **скопировать на ПК с Windows** → **восстановить в контейнер** (например `mp-servis-postgres` на `127.0.0.1:5433`) → **миграции** → **`uploads/`** → **запуск API**.

Имена контейнера, путей и пользователя подставьте свои, если отличаются.

---

## Часть A. На старом VPS (Linux), где крутится рабочий API

### A1. Узнать параметры подключения к БД

Обычно в **`/opt/mp-servis/api/.env`** (или где у вас лежит backend):

```bash
grep '^DATABASE_URL=' /opt/mp-servis/api/.env
```

Запомните: хост (часто `127.0.0.1`), порт, пользователь, имя базы (часто **`mp_servis`**).

### A2. Снять дамп в формате custom (`-Fc`) — удобно для `pg_restore`

Под пользователем с доступом к БД (часто **`postgres`** или роль из `DATABASE_URL`):

```bash
# пример: локальный Postgres на VPS, база mp_servis
sudo -u postgres pg_dump -h 127.0.0.1 -p 5432 -U mp_servis_app -d mp_servis -Fc -f /tmp/mp_servis.dump
```

Если пароль спросит интерактивно — введите. Для неинтерактивно можно `PGPASSWORD=...` (осторожно с историей команд):

```bash
export PGPASSWORD='ВАШ_ПАРОЛЬ'
sudo -u postgres pg_dump -h 127.0.0.1 -p 5432 -U mp_servis_app -d mp_servis -Fc -f /tmp/mp_servis.dump
unset PGPASSWORD
```

Проверка размера:

```bash
ls -lh /tmp/mp_servis.dump
```

### A3. (Рекомендуется) Архив папки `uploads` с VPS

Файлы фото и вложений **не в дампе БД**, они на диске рядом с API:

```bash
sudo tar -czf /tmp/mp_uploads.tgz -C /opt/mp-servis/api uploads
ls -lh /tmp/mp_uploads.tgz
```

Путь **`/opt/mp-servis/api`** замените на ваш, если другой.

### A4. Скопировать файлы на Windows-ПК

**Вариант 1 — `scp` на ваш ПК** (с Windows в PowerShell, если есть SSH к VPS):

```powershell
scp USER@VPS_IP:/tmp/mp_servis.dump "D:\обмен\ДА\MP\mp_servis.dump"
scp USER@VPS_IP:/tmp/mp_uploads.tgz "D:\обмен\ДА\MP\mp_uploads.tgz"
```

**Вариант 2** — любой облачный диск / флешка / общая папка `D:\обмен\...`.

---

## Часть B. На Windows (Docker Postgres уже есть, например `mp-servis-postgres`)

### B1. Остановить API Nest

Чтобы не было открытых соединений к БД при `DROP DATABASE`:

```powershell
Get-NetTCPConnection -LocalPort 3001 -State Listen -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
```

(Порт **`3001`** замените на ваш **`PORT`** из `backend\.env`.)

### B2. Положить дамп и (если есть) архив uploads

Например:

- `D:\обмен\ДА\MP\mp_servis.dump`
- `D:\обмен\ДА\MP\mp_uploads.tgz`

### B3. Пересоздать пустую базу внутри контейнера и восстановить дамп

Имя контейнера: **`mp-servis-postgres`**. Суперпользователь в образе — тот, что в **`POSTGRES_USER`** (у вас может быть **`mp_servis_app`**).

```powershell
$dump = "D:\обмен\ДА\MP\mp_servis.dump"
$ctr = "mp-servis-postgres"
$pgUser = "mp_servis_app"

docker exec $ctr psql -U $pgUser -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'mp_servis' AND pid <> pg_backend_pid();"
docker exec $ctr psql -U $pgUser -d postgres -c "DROP DATABASE IF EXISTS mp_servis;"
docker exec $ctr psql -U $pgUser -d postgres -c "CREATE DATABASE mp_servis OWNER $pgUser;"

docker cp $dump "${ctr}:/tmp/mp_servis.dump"
docker exec $ctr pg_restore -U $pgUser -d mp_servis --no-owner --role=$pgUser /tmp/mp_servis.dump
```

Если `pg_restore` ругается на права/роли, попробуйте:

```powershell
docker exec $ctr pg_restore -U $pgUser -d mp_servis --no-owner --no-acl /tmp/mp_servis.dump
```

Ошибки вида «уже существует» для отдельных объектов при повторном restore иногда допустимы; если restore завершился с кодом не 0 — пришлите последние 30 строк лога.

Проверка таблиц:

```powershell
docker exec $ctr psql -U $pgUser -d mp_servis -c "\dt" | Select-Object -First 40
```

### B4. Распаковать `uploads` в backend

```powershell
cd "D:\обмен\ДА\MP\backend"
if (Test-Path "uploads") { Remove-Item -Recurse -Force "uploads" }
tar -xzf "D:\обмен\ДА\MP\mp_uploads.tgz"
```

Если архива не было — пропустите; тогда в приложении не будет старых файлов с диска.

### B5. `backend\.env`

Убедитесь, что **`DATABASE_URL`** указывает на **Docker** (пример):

```env
DATABASE_URL=postgresql://mp_servis_app:ВАШ_ПАРОЛЬ@127.0.0.1:5433/mp_servis
PORT=3001
LISTEN_HOST=0.0.0.0
API_BASE_URL=http://192.168.1.145:3001/api/v1
NODE_ENV=production
```

Пароль в URL должен совпадать с **`POSTGRES_PASSWORD`** контейнера (если меняли — синхронизируйте).

### B6. Миграции и сборка (после дампа)

Из папки **`backend`** (нужны зависимости до `prune`):

```powershell
cd "D:\обмен\ДА\MP\backend"
npm ci
npm run build
npm run migration:run:prod
```

Если миграции пишут «уже применено» / пропускают — нормально: в дампе уже есть таблица **`migrations`**. Важно, чтобы дошли до конца без фатальной ошибки.

```powershell
npm prune --omit=dev
```

### B7. Запуск API

```powershell
$env:NODE_ENV = "production"
Start-Process -FilePath (Get-Command node).Source -ArgumentList "--env-file=.env","dist/src/main.js" -WorkingDirectory "D:\обмен\ДА\MP\backend" -WindowStyle Hidden
```

Или скрипт (чтобы не трогать службу PostgreSQL 12 на 5432):

```powershell
powershell -ExecutionPolicy Bypass -File "D:\обмен\ДА\MP\backend\deploy\update_and_run_backend_windows_lan.ps1" -SkipPostgresStart
```

(Если скрипт снова делает `npm ci` — это ок; главное, чтобы **`DATABASE_URL`** уже был правильным.)

Проверка:

```powershell
Invoke-WebRequest -Uri "http://127.0.0.1:3001/api/v1/reference/car-brands" -UseBasicParsing | Select-Object StatusCode
```

---

## Если на VPS нет `pg_dump` или нет доступа

```bash
sudo apt install -y postgresql-client
```

или используйте **`pg_dump`** из того же Docker/образа Postgres, что и на VPS.

---

## Краткий чеклист

| Шаг | Где | Действие |
|-----|-----|----------|
| 1 | VPS | `pg_dump ... -Fc` → `mp_servis.dump` |
| 2 | VPS | `tar -czf` каталога **`uploads`** |
| 3 | Сеть | Скопировать `.dump` и `.tgz` на Windows |
| 4 | Windows | Остановить API на порту приложения |
| 5 | Docker | `DROP/CREATE DATABASE`, `pg_restore` |
| 6 | Windows | Распаковать **`uploads`** в `backend\uploads` |
| 7 | `.env` | **`DATABASE_URL`** → `127.0.0.1:5433` и нужный пользователь |
| 8 | `backend` | `npm ci` → `build` → `migration:run:prod` → `prune` |
| 9 | Windows | Запуск `node dist/src/main.js` |

---

## Пустая БД без VPS (только демо)

Если дампа **нет** и нужна **новая** схема без старых данных — см. комментарии в `backend/scripts/bootstrap-local-schema.ts` и команду **`npm run db:bootstrap`** с **`DB_BOOTSTRAP_RESET=1`** (только для осознанного сценария, не как замена переносу прода).

Связанный документ: **`SETUP_WINDOWS_LAN_SERVER_RU.md`**.
