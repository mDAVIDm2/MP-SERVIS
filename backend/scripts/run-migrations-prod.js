/**
 * Запуск миграций на сервере после `npm ci --omit=dev` и `npm run build`.
 * Использует скомпилированные .js из dist/src/database/migrations/ (после nest build).
 *
 * Запуск из корня backend:
 *   node --env-file=.env scripts/run-migrations-prod.js
 * или: npm run migration:run:prod
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { DataSource } = require('typeorm');

const root = path.join(__dirname, '..');
/** Nest CLI кладёт сборку в dist/src/ (не в dist/). */
const migrationsDir = path.join(root, 'dist', 'src', 'database', 'migrations');
const migrationsGlob = path.join(migrationsDir, '*.js');

async function main() {
  const url = process.env.DATABASE_URL;
  if (!url) {
    console.error('DATABASE_URL не задан (.env или окружение)');
    process.exit(1);
  }

  if (!fs.existsSync(migrationsDir)) {
    console.error(
      `Папка миграций не найдена: ${migrationsDir}\nСначала выполните: npm run build`,
    );
    process.exit(1);
  }
  const migFiles = fs.readdirSync(migrationsDir).filter((f) => f.endsWith('.js'));
  if (migFiles.length === 0) {
    console.error(`Нет .js миграций в ${migrationsDir} — проверьте сборку (npm run build).`);
    process.exit(1);
  }

  const ds = new DataSource({
    type: 'postgres',
    url,
    migrations: [migrationsGlob],
    synchronize: false,
    logging: true,
  });

  await ds.initialize();
  const executed = await ds.runMigrations();
  console.log(
    executed.length
      ? `Выполнено миграций: ${executed.map((m) => m.name).join(', ')}`
      : 'Новых миграций нет',
  );
  await ds.destroy();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
