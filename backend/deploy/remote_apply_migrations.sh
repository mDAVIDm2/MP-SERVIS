#!/usr/bin/env bash
# Выполнить на сервере из /root после загрузки /tmp/mp-backend-deploy.tgz
set -euo pipefail
API_DIR=/opt/mp-servis/api
ARCHIVE=/tmp/mp-backend-deploy.tgz

if [[ ! -f "$ARCHIVE" ]]; then
  echo "Нет архива: $ARCHIVE"
  exit 1
fi

systemctl stop mp-servis-api || true
cd "$API_DIR"
sudo -u mpservis tar -xzf "$ARCHIVE"
chown -R mpservis:mpservis "$API_DIR"

sudo -u mpservis bash -lc "cd $API_DIR && npm ci && npm run build && npm run migration:run:prod && npm prune --omit=dev"

systemctl start mp-servis-api
sleep 2
systemctl is-active mp-servis-api
curl -sS -o /dev/null -w "HTTP %{http_code}\n" "http://127.0.0.1:3000/api/v1/reference/car-brands" || true
