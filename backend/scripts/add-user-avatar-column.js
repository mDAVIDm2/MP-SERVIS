/**
 * Добавляет колонку users.avatar_url (после обновления сущности User без synchronize).
 * Запуск: node scripts/add-user-avatar-column.js   или   npm run db:add-user-avatar-column
 */
try {
  require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
} catch (_) {}

const { Client } = require('pg');

const defaultUrl = 'postgresql://postgres:postgres@localhost:5432/mp_servis';
const url = process.env.DATABASE_URL || defaultUrl;

async function main() {
  const client = new Client({ connectionString: url });
  try {
    await client.connect();
    await client.query(
      'ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url varchar(1024) NULL',
    );
    console.log('OK: колонка users.avatar_url добавлена (или уже была).');
  } catch (e) {
    console.error('Ошибка:', e.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

main();
