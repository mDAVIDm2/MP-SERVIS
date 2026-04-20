/**
 * Создаёт базу данных mp_servis, если её ещё нет.
 * Запуск: node scripts/create-db.js   или   npm run db:create
 * Требуется: PostgreSQL запущен. URL из .env (DATABASE_URL) или по умолчанию.
 */
// Опционально: загрузить .env (npm i dotenv)
try {
  require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
} catch (_) {}

const { Client } = require('pg');

const defaultUrl = 'postgresql://postgres:postgres@localhost:5432/mp_servis';
const url = process.env.DATABASE_URL || defaultUrl;

// Подключаемся к служебной БД postgres (всегда есть)
const urlToPostgres = url.replace(/\/[^/]+\?.*$|\/[^/]+$/, '/postgres');

async function main() {
  const client = new Client({ connectionString: urlToPostgres });
  try {
    await client.connect();
    const res = await client.query(
      "SELECT 1 FROM pg_database WHERE datname = 'mp_servis'"
    );
    if (res.rows.length === 0) {
      await client.query('CREATE DATABASE mp_servis');
      console.log('База данных mp_servis создана.');
    } else {
      console.log('База данных mp_servis уже существует.');
    }
  } catch (e) {
    console.error('Ошибка:', e.message);
    if (e.code === 'ECONNREFUSED') {
      console.error('Убедитесь, что PostgreSQL запущен на localhost:5432');
    }
    process.exit(1);
  } finally {
    await client.end();
  }
}

main();
