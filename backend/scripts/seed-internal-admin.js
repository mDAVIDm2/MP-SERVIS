/**
 * Создаёт или обновляет суперадмина Control Center из .env (INITIAL_SUPERADMIN_EMAIL, INITIAL_SUPERADMIN_PASSWORD).
 * Запуск из папки backend: npm run seed:internal
 */
const path = require('path');
const { randomUUID } = require('crypto');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const { Client } = require('pg');
const bcrypt = require('bcrypt');

const SALT_ROUNDS = 10;
const defaultUrl = 'postgresql://postgres:postgres@localhost:5432/mp_servis';
const url = process.env.DATABASE_URL || defaultUrl;
const email = (process.env.INITIAL_SUPERADMIN_EMAIL || '').trim().toLowerCase();
const password = (process.env.INITIAL_SUPERADMIN_PASSWORD || '').trim();

async function main() {
  if (!email || !password) {
    console.error('Укажите в .env: INITIAL_SUPERADMIN_EMAIL и INITIAL_SUPERADMIN_PASSWORD');
    process.exit(1);
  }
  const client = new Client({ connectionString: url });
  try {
    await client.connect();
    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);
    await client.query(
      `INSERT INTO internal_operators (id, email, password_hash, name, role, is_active, created_at)
       VALUES ($1, $2, $3, 'Суперадмин', 'superadmin', true, now())
       ON CONFLICT (email) DO UPDATE SET
         password_hash = EXCLUDED.password_hash,
         name = EXCLUDED.name,
         role = EXCLUDED.role,
         is_active = true`,
      [randomUUID(), email, passwordHash]
    );
    console.log('Суперадмин создан/обновлён:', email);
  } catch (e) {
    console.error('Ошибка:', e.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

main();
