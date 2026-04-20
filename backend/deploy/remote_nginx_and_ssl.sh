#!/usr/bin/env bash
# Запуск на сервере от root. Nginx всегда; certbot — только если DNS уже указывает на этот сервер.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx curl

cat >/etc/nginx/sites-available/mp-servis-api <<'NGX'
server {
    listen 80;
    listen [::]:80;
    server_name api.mp-servis.ru;

    client_max_body_size 20m;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
NGX

ln -sf /etc/nginx/sites-available/mp-servis-api /etc/nginx/sites-enabled/mp-servis-api
nginx -t
systemctl enable nginx
systemctl reload nginx
systemctl is-active nginx

if command -v ufw >/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
  ufw allow 'Nginx Full' || true
fi

echo "=== Проверка DNS с сервера ==="
if getent hosts api.mp-servis.ru | grep -q '217.114.0.114'; then
  echo "DNS совпадает с VPS — пробуем certbot"
  apt-get install -y certbot python3-certbot-nginx
  certbot --nginx -d api.mp-servis.ru --non-interactive --agree-tos \
    -m admin@mp-servis.ru --redirect --expand || true
  if [ -f /opt/mp-servis/api/.env ]; then
    sed -i 's|^API_BASE_URL=.*|API_BASE_URL=https://api.mp-servis.ru/api/v1|' /opt/mp-servis/api/.env
    chown mpservis:mpservis /opt/mp-servis/api/.env 2>/dev/null || true
    systemctl restart mp-servis-api 2>/dev/null || true
  fi
  curl -sS -o /dev/null -w "HTTPS car-brands HTTP %{http_code}\n" https://api.mp-servis.ru/api/v1/reference/car-brands || true
else
  echo "DNS api.mp-servis.ru ещё не указывает на 217.114.0.114 — certbot пропущен."
  echo "Когда запись A будет готова:"
  echo "  apt install -y certbot python3-certbot-nginx"
  echo "  certbot --nginx -d api.mp-servis.ru --non-interactive --agree-tos -m ВАШ@EMAIL --redirect"
  echo "  sed -i 's|^API_BASE_URL=.*|API_BASE_URL=https://api.mp-servis.ru/api/v1|' /opt/mp-servis/api/.env"
  echo "  systemctl restart mp-servis-api"
fi
