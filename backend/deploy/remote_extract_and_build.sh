#!/usr/bin/env bash
set -euo pipefail
cd /opt/mp-servis/api
rm -rf ./*
tar -xzf /tmp/mp-backend.tgz -C /opt/mp-servis/api
chown -R mpservis:mpservis /opt/mp-servis/api

python3 <<'PY'
import pathlib
sec_path = pathlib.Path("/root/mp_servis_secrets.txt")
secrets = {}
for line in sec_path.read_text(encoding="utf-8").splitlines():
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    if "=" not in line:
        continue
    k, v = line.split("=", 1)
    secrets[k.strip()] = v.strip()

db = secrets.get("DATABASE_URL", "")
jwt = secrets.get("JWT_SECRET", "")
apw = secrets.get("INITIAL_SUPERADMIN_PASSWORD", "")

env_text = f"""NODE_ENV=production
PORT=3000
DATABASE_URL={db}
JWT_SECRET={jwt}
JWT_EXPIRES_IN=7d
JWT_ACCESS_EXPIRES_IN=15m
OTP_DELIVERY_PROVIDER=console
API_BASE_URL=http://217.114.0.114:3000/api/v1
INITIAL_SUPERADMIN_EMAIL=admin@mp-servis.local
INITIAL_SUPERADMIN_PASSWORD={apw}
"""
pathlib.Path("/opt/mp-servis/api/.env").write_text(env_text, encoding="utf-8")
PY

chmod 600 /opt/mp-servis/api/.env
chown mpservis:mpservis /opt/mp-servis/api/.env

# Пустая БД: сначала схема из сущностей + таблица migrations (см. scripts/bootstrap-local-schema.ts)
sudo -u mpservis bash -c 'cd /opt/mp-servis/api && npm ci && DB_BOOTSTRAP_RESET=1 npm run db:bootstrap && npm run build && npm run migration:run:prod && npm prune --omit=dev && mkdir -p uploads'

cp /opt/mp-servis/api/deploy/systemd/mp-servis-api.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now mp-servis-api
sleep 2
systemctl is-active mp-servis-api
curl -sS -o /dev/null -w "%{http_code}" http://127.0.0.1:3000/api/v1/reference/car-brands || true
