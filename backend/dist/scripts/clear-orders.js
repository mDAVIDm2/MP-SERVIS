"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const typeorm_1 = require("typeorm");
const dataSource = new typeorm_1.DataSource({
    type: 'postgres',
    url: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/mp_servis',
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
    }
    finally {
        await qr.release();
        await dataSource.destroy();
    }
}
run().catch((e) => {
    console.error(e);
    process.exit(1);
});
//# sourceMappingURL=clear-orders.js.map