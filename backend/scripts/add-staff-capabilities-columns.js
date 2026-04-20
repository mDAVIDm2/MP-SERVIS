/**
 * Добавляет колонки staff_members.can_see_chats, can_write_chats, can_manage_org_settings
 * и выставляет значения по роли (мастер / админ).
 *
 * Запуск: npm run db:add-staff-capabilities
 */
try {
  require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
} catch (_) {}

const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

const defaultUrl = 'postgresql://postgres:postgres@localhost:5432/mp_servis';
const url = process.env.DATABASE_URL || defaultUrl;

async function main() {
  const sqlPath = path.join(__dirname, '../migrations/20260402_staff_capabilities.sql');
  const sql = fs.readFileSync(sqlPath, 'utf8');
  const client = new Client({ connectionString: url });
  try {
    await client.connect();
    await client.query(sql);
    console.log('OK: миграция staff_capabilities применена (или колонки уже были).');
  } catch (e) {
    console.error('Ошибка:', e.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

main();
