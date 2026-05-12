# MP-Servis API на ПК в локальной сети (Windows)

Типовой сервер разработки/площадки: **Windows**, IP в LAN **`192.168.1.145`**, репозиторий **`D:\обмен\ДА\MP`**, API слушает **`0.0.0.0:3001`** (порт **3001**, если **3000** занят IIS или другим сервисом).

Публичный URL API для приложений в той же Wi‑Fi сети:

- **HTTP API:** `http://192.168.1.145:3001/api/v1`
- **WebSocket (чаты, опционально):** `ws://192.168.1.145:3001/ws`

PostgreSQL обычно на **этой же машине**, порт **`5432`** (внешний доступ не обязателен — только localhost).

---

## Порты (кратко)

| Сервис | Порт | Куда смотрит |
|--------|------|----------------|
| Nest API | **3001** | `PORT` в `backend\.env` |
| PostgreSQL | **5432** | `DATABASE_URL` в `backend\.env` |
| Другое (IIS и т.д.) | часто **3000** | не используем под Nest, если занят |

В **`backend\.env`** на сервере должны быть согласованы:

```env
PORT=3001
LISTEN_HOST=0.0.0.0
API_BASE_URL=http://192.168.1.145:3001/api/v1
```

`API_BASE_URL` — то, что попадает в ссылки в письмах и в абсолютные URL в ответах; для LAN укажите реальный `http://<IP>:3001/api/v1`.

**CORS (`ALLOWED_ORIGINS`):** для нативных Android/iOS `Origin` часто нет; для **Flutter Web** перечислите origin’ы веб-сборки через запятую. Пример:

```env
ALLOWED_ORIGINS=http://localhost:8080,http://127.0.0.1:8080
```

При необходимости добавьте origin дев-сервера Vite/Flutter Web.

**Брандмауэр Windows:** разрешите входящий **TCP 3001** (и **5432** только если к БД подключаются с других машин — для типичной схемы API+PG на одном ПК достаточно открыть **3001**):

```powershell
New-NetFirewallRule -DisplayName "MP-Servis API 3001" -Direction Inbound -LocalPort 3001 -Protocol TCP -Action Allow
```

---

## Репозиторий

```text
https://github.com/mDAVIDm2/MP-SERVIS.git
```

Рабочая копия на сервере:

```text
D:\обмен\ДА\MP
```

Код API:

```text
D:\обмен\ДА\MP\backend
```

---

## Первый раз: клонирование

```powershell
New-Item -ItemType Directory -Path "D:\обмен\ДА" -Force | Out-Null
Set-Location "D:\обмен\ДА"
git clone https://github.com/mDAVIDm2/MP-SERVIS.git MP
```

Дальше: PostgreSQL, `backend\.env` (скопируйте с `backend\.env.example` или `backend\deploy\.env.production.example` и заполните), затем в `backend`:

```powershell
Set-Location "D:\обмен\ДА\MP\backend"
npm ci
npm run build
npm run migration:run:prod
```

Подробнее про первичную установку Windows см. `install_on_windows_server.ps1` (сценарий с дампом БД — по желанию).

---

## Один скрипт: БД, git, сборка, миграции, запуск API

В репозитории: **`backend/deploy/update_and_run_backend_windows_lan.ps1`**.

На сервере (из папки `deploy` или с путём к скрипту):

```powershell
cd D:\обмен\ДА\MP\backend\deploy
powershell -ExecutionPolicy Bypass -File .\update_and_run_backend_windows_lan.ps1
```

По шагам скрипт: **поднимает службу PostgreSQL** (имя `postgresql*` или задайте `-PostgresServiceName`), **останавливает Node**, **`git fetch` + `checkout` + `pull`** (или `-HardReset` вместо pull), **`npm ci` → `build` → `migration:run:prod` → `prune`**, **запускает** `node --env-file=.env dist/src/main.js` и проверяет HTTP.

Параметры: см. комментарии в начале файла. Текст логов в скрипте на английском (кодировка PowerShell 5.1). Корень репо по умолчанию вычисляется от расположения скрипта; иначе **`MP_LAN_REPO_ROOT`** или **`-RepoRoot`**.

---

## Обновление бэкенда после изменений в Git

Выполняйте на **192.168.1.145** в PowerShell.

### 1. Остановить процесс Node (освободить порты и файлы `node_modules`, в т.ч. `sharp`)

```powershell
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force
Get-NetTCPConnection -LocalPort 3001 -State Listen -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
```

### 2. Подтянуть код

```powershell
Set-Location "D:\обмен\ДА\MP"
git fetch origin
git checkout master
git pull origin master
```

Если **`git pull`** ругается на локальные изменения в **`backend/dist`** (старый клон, когда `dist` ещё отслеживался), после остановки Node выполните один раз:

```powershell
Set-Location "D:\обмен\ДА\MP"
git fetch origin
git reset --hard origin/master
```

Незакоммиченный **`backend\.env`** и папка **`uploads`** не удаляются (они не в Git или в `.gitignore`). Локальные незакоммиченные правки **в отслеживаемых файлах** сотрутся — при необходимости сначала сохраните их вручную.

### 3. Сборка и миграции

```powershell
Set-Location "D:\обмен\ДА\MP\backend"
npm ci
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
npm run build
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
npm run migration:run:prod
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
npm prune --omit=dev
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
```

### 4. Запуск API (production)

```powershell
$env:NODE_ENV = "production"
Set-Location "D:\обмен\ДА\MP\backend"
Start-Process -FilePath (Get-Command node).Source -ArgumentList "--env-file=.env","dist/src/main.js" -WorkingDirectory "D:\обмен\ДА\MP\backend" -WindowStyle Hidden
```

### 5. Проверка

```powershell
Invoke-WebRequest -Uri "http://127.0.0.1:3001/api/v1/reference/car-brands" -UseBasicParsing | Select-Object StatusCode
```

Ожидается **`200`**. С другого ПК в LAN:

```powershell
Invoke-WebRequest -Uri "http://192.168.1.145:3001/api/v1/reference/car-brands" -UseBasicParsing | Select-Object StatusCode
```

---

## Альтернатива: выкладка по SSH с машины разработчика

С вашего ПК (где настроен SSH `Host mp-servis` → `192.168.1.145` в `%USERPROFILE%\.ssh\config`):

```powershell
cd C:\dev\MP\backend\deploy
.\push_backend_to_lan_windows.ps1
```

Параметры по умолчанию: `SshTarget=mp-servis`, `RemoteBackend=D:\обмен\ДА\MP\backend`. Переопределение: см. комментарии в начале `push_backend_to_lan_windows.ps1` и переменные окружения `MP_DEPLOY_*`.

---

## Приложения Flutter (телефон / эмулятор / десктоп)

Базовый URL должен совпадать с **`API_BASE_URL`** и портом **`3001`**.

Примеры:

```text
flutter run --dart-define=MP_SERVIS_API_HOST=192.168.1.145 --dart-define=MP_SERVIS_API_PORT=3001
```

или полный URL:

```text
flutter run --dart-define=MP_SERVIS_API_BASE_URL=http://192.168.1.145:3001/api/v1
```

**Android эмулятор** к хосту ПК: часто `10.0.2.2` вместо LAN IP:

```text
flutter run --dart-define=MP_SERVIS_API_HOST=10.0.2.2 --dart-define=MP_SERVIS_API_PORT=3001
```

**USB + adb reverse:**

```text
adb reverse tcp:3001 tcp:3001
flutter run --dart-define=MP_SERVIS_API_HOST=127.0.0.1 --dart-define=MP_SERVIS_API_PORT=3001
```

По умолчанию в коде клиентов порт для режима «только хост» задаётся **`MP_SERVIS_API_PORT`** (если не передан — **3001**). См. `autohub_client2/lib/core/config/app_config.dart` и `autohub_business/lib/core/config/app_config.dart`.

---

## Сводка

| Что | Значение |
|-----|----------|
| IP API в LAN | `192.168.1.145` |
| Порт API | `3001` |
| Base URL | `http://192.168.1.145:3001/api/v1` |
| Путь к репо | `D:\обмен\ДА\MP` |
| Git remote | `https://github.com/mDAVIDm2/MP-SERVIS.git` |
| Ветка | `master` |

Документ по **Linux VPS** (другая схема): `SETUP_SERVER_RU.md` в этой же папке.
