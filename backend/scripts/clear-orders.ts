/**
 * Скрипт очистки всей истории заказов в БД.
 * Удаляет: order_photos, order_items, orders. Обнуляет order_id в chats и chat_messages.
 *
 * Запуск из папки backend: npx ts-node scripts/clear-orders.ts
 * Или: npm run clear-orders
 */

import { DataSource } from 'typeorm';

const dataSource = new DataSource({
  type: 'postgres',
  url: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/autohub',
  entities: [],
  synchronize: false,
});

async function run() {
  await dataSource.initialize();
  const qr = dataSource.createQueryRunner();
  await qr.connect();
  try {
    console.log('[clear-orders] Начинаю очистку заказов...');
    await qr.query('DELETE FROM order_photos');
    console.log('[clear-orders] Удалены order_photos');
    await qr.query('DELETE FROM order_items');
    console.log('[clear-orders] Удалены order_items');
    await qr.query('UPDATE chat_messages SET order_id = NULL WHERE order_id IS NOT NULL');
    console.log('[clear-orders] Обнулены order_id в chat_messages');
    await qr.query('UPDATE chats SET order_id = NULL WHERE order_id IS NOT NULL');
    console.log('[clear-orders] Обнулены order_id в chats');
    await qr.query('DELETE FROM orders');
    console.log('[clear-orders] Удалены orders. Готово.');
  } finally {
    await qr.release();
    await dataSource.destroy();
  }
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
