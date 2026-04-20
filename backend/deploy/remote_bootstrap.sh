#!/usr/bin/env bash
# Выполняется на Ubuntu 24.04 от root. Не содержит секретов — пароли генерируются на сервере.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "=== apt update / upgrade ==="
apt-get update -y
apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

echo "=== пользователь mpservis ==="
if ! id mpservis &>/dev/null; then
  useradd --system --home-dir /opt/mp-servis --shell /usr/sbin/nologin mpservis
fi
mkdir -p /opt/mp-servis/api
chown -R mpservis:mpservis /opt/mp-servis

echo "=== Node.js 20 ==="
if ! command -v node &>/dev/null || [[ "$(node -v 2>/dev/null)" != v20* ]]; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs build-essential
fi
node -v
npm -v

echo "=== PostgreSQL ==="
apt-get install -y postgresql postgresql-contrib
systemctl enable --now postgresql

DB_PASS=$(openssl rand -hex 16)
JWT_SECRET=$(openssl rand -base64 48 | tr -d '\n')
ADMIN_PASS=$(openssl rand -base64 12 | tr -d '\n')

CREDS=/root/mp_servis_secrets.txt
{
  echo "# Создано $(date -u +%Y-%m-%dT%H:%M:%SZ). Храните в безопасности."
  echo "DATABASE_URL=postgresql://mp_servis_app:${DB_PASS}@127.0.0.1:5432/mp_servis"
  echo "JWT_SECRET=${JWT_SECRET}"
  echo "INITIAL_SUPERADMIN_PASSWORD=${ADMIN_PASS}"
} > "$CREDS"
chmod 600 "$CREDS"

echo "=== База mp_servis ==="
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='mp_servis_app'" | grep -q 1; then
  sudo -u postgres psql -v ON_ERROR_STOP=1 -c "ALTER USER mp_servis_app WITH PASSWORD '${DB_PASS}';"
else
  sudo -u postgres psql -v ON_ERROR_STOP=1 -c "CREATE USER mp_servis_app WITH PASSWORD '${DB_PASS}';"
fi

if sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='mp_servis'" | grep -q 1; then
  echo "БД mp_servis уже существует"
else
  sudo -u postgres psql -v ON_ERROR_STOP=1 -c "CREATE DATABASE mp_servis OWNER mp_servis_app;"
fi

sudo -u postgres psql -v ON_ERROR_STOP=1 -d mp_servis <<EOSQL
GRANT ALL ON SCHEMA public TO mp_servis_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO mp_servis_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO mp_servis_app;
EOSQL

echo "=== готово до загрузки кода ==="
echo "Секреты: $CREDS"
cat "$CREDS"
