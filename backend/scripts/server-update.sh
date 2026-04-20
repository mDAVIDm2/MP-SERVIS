#!/usr/bin/env bash
# Обновление бэкенда на Linux-сервере (из каталога backend после git pull).
# Требуется: Node 20+, .env с DATABASE_URL, PM2/systemd по желанию перезапустить вручную.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== npm ci (production) =="
npm ci --omit=dev

echo "== nest build =="
npm run build

echo "== typeorm migrations (compiled dist) =="
node --env-file=.env scripts/run-migrations-prod.js

echo "== готово =="
echo "Перезапустите процесс Nest (pm2 restart / systemctl restart …)."
