/**
 * Удаляет из internal_operators строки с NULL в email (из-за этого падает synchronize).
 * Запуск: node scripts/fix-internal-operators-null-email.js
 */
const path = require('path');
try {
  require('dotenv').config({ path: path.join(__dirname, '../.env') });
} catch (_) {}

const { Client } = require('pg');

const defaultUrl = 'postgresql://postgres:postgres@localhost:5432/autohub';
const url = process.env.DATABASE_URL || defaultUrl;

async function main() {
  const client = new Client({ connectionString: url });
  try {
    await client.connect();
    const res = await client.query(
      'DELETE FROM internal_operators WHERE email IS NULL RETURNING id'
    );
    const deleted = res.rowCount || 0;
    if (deleted > 0) {
      console.log('Удалено записей с NULL email:', deleted);
    } else {
      console.log('Записей с NULL email не найдено.');
    }
  } catch (e) {
    console.error('Ошибка:', e.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

main();
