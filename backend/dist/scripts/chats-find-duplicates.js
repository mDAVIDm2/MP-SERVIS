"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const typeorm_1 = require("typeorm");
async function main() {
    const ds = new typeorm_1.DataSource({
        type: 'postgres',
        host: process.env.DB_HOST || 'localhost',
        port: parseInt(process.env.DB_PORT || '5432', 10),
        username: process.env.DB_USERNAME || 'postgres',
        password: process.env.DB_PASSWORD || 'postgres',
        database: process.env.DB_DATABASE || 'autohub',
        entities: [],
        synchronize: false,
    });
    await ds.initialize();
    const q = ds.createQueryRunner();
    const rows = await q.query(`
    SELECT organization_id, client_phone, COUNT(*) AS cnt, array_agg(id ORDER BY id) AS chat_ids
    FROM chats
    WHERE organization_id IS NOT NULL AND client_phone IS NOT NULL AND client_phone != ''
    GROUP BY organization_id, client_phone
    HAVING COUNT(*) > 1
  `);
    await q.release();
    await ds.destroy();
    if (rows.length === 0) {
        console.log('Дубликатов (org, client_phone) не найдено.');
        return;
    }
    console.log('Найдены дубликаты чатов (organization_id, client_phone):');
    for (const r of rows) {
        console.log(`  org=${r.organization_id} phone=***${(r.client_phone || '').slice(-4)} count=${r.cnt} chat_ids=${r.chat_ids}`);
    }
}
main().catch((e) => {
    console.error(e);
    process.exit(1);
});
//# sourceMappingURL=chats-find-duplicates.js.map