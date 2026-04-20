#!/usr/bin/env bash
# Запуск на VPS от root: переключает DATABASE_URL на пользователя mp_servis_app.
# Использование:
#   scp deploy/switch_to_app_db_user.sh root@VPS:/tmp/
#   ssh root@VPS 'bash /tmp/switch_to_app_db_user.sh'
#
# Генерирует новый пароль для mp_servis_app, обновляет /opt/mp-servis/api/.env,
# выполняет миграции и перезапускает mp-servis-api.
set -euo pipefail

API_DIR="${API_DIR:-/opt/mp-servis/api}"
ENV_FILE="$API_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Нет файла $ENV_FILE" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Нужен python3" >&2
  exit 1
fi

# Пароль только [A-Za-z0-9] — удобно для URL и psql
PW=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 40)

cp -a "$ENV_FILE" "${ENV_FILE}.bak_before_mp_servis_app"

sudo -u postgres psql -v ON_ERROR_STOP=1 -d postgres <<SQL
ALTER ROLE mp_servis_app WITH LOGIN PASSWORD '${PW}';
SQL

sudo -u postgres psql -v ON_ERROR_STOP=1 -d mp_servis <<SQL
GRANT CONNECT ON DATABASE mp_servis TO mp_servis_app;
GRANT USAGE ON SCHEMA public TO mp_servis_app;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO mp_servis_app;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO mp_servis_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO mp_servis_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO mp_servis_app;
SQL

ENC_PW=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$PW")
NEW_URL="postgresql://mp_servis_app:${ENC_PW}@localhost:5432/mp_servis"

export NEW_URL
export ENV_FILE
python3 <<'PY'
import os
from pathlib import Path
path = Path(os.environ["ENV_FILE"])
new_url = os.environ["NEW_URL"]
lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
out = []
found = False
for line in lines:
    if line.startswith("DATABASE_URL="):
        out.append(f"DATABASE_URL={new_url}\n")
        found = True
    else:
        out.append(line)
if not found:
    out.append(f"DATABASE_URL={new_url}\n")
path.write_text("".join(out), encoding="utf-8")
PY
unset NEW_URL ENV_FILE

chmod 600 "$API_DIR/.env"
chown mpservis:mpservis "$API_DIR/.env"

cd "$API_DIR"
sudo -u mpservis npm run migration:run:prod
sudo systemctl restart mp-servis-api
sleep 2
systemctl is-active mp-servis-api
curl -sS -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:3000/api/v1/reference/car-brands

echo "Готово: API использует mp_servis_app. Резервная копия: ${API_DIR}/.env.bak_before_mp_servis_app"
