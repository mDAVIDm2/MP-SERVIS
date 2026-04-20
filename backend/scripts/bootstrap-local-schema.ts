/**
 * Первичная схема для локальной БД: TypeORM synchronize по сущностям,
 * затем запись в migrations — чтобы npm run migration:run не пытался заново
 * выполнить ALTER-миграции (они рассчитаны на уже существующую схему).
 *
 * Запуск: npm run db:bootstrap
 *
 * Если в БД уже были таблицы/строки и sync падает (например NOT NULL на email),
 * полный сброс схемы public:
 *   set DB_BOOTSTRAP_RESET=1 && npm run db:bootstrap   (Windows cmd)
 *   $env:DB_BOOTSTRAP_RESET='1'; npm run db:bootstrap   (PowerShell)
 *
 * Для продакшена не использовать сброс — только дамп / миграции.
 */
import * as path from 'path';

try {
  require('dotenv').config({ path: path.join(__dirname, '../.env') });
} catch {
  /* optional */
}

import { DataSource } from 'typeorm';

const rootDir = path.join(__dirname, '..');

/** Windows: TypeORM glob не матчится с обратными слэшами. */
function entitiesGlob(): string {
  return path.join(rootDir, 'src', '**', '*.entity{.ts,.js}').replace(/\\/g, '/');
}

/** Порядок как у TypeORM migration:run (timestamp ASC). */
const APPLIED_MIGRATIONS: { timestamp: number; name: string }[] = [
  { timestamp: 1730000000000, name: 'AddProposedDateTimeToChatMessages1730000000000' },
  { timestamp: 1730200000000, name: 'OrderMasterToStaffMember1730200000000' },
  { timestamp: 1730300000000, name: 'SmartScheduling1730300000000' },
  { timestamp: 1730400000000, name: 'OrderPreviousStatusAndChatMessageIsSystem1730400000000' },
  { timestamp: 1730500000000, name: 'OrganizationTimezone1730500000000' },
  { timestamp: 1730600000000, name: 'AddUserIdToStaffMembers1730600000000' },
  { timestamp: 1731100000000, name: 'FixInternalOperatorsEmailNotNull1731100000000' },
  { timestamp: 1731200000000, name: 'OrganizationSubscriptions1731200000000' },
  { timestamp: 1731300000000, name: 'NotificationsTable1731300000000' },
  { timestamp: 1731400000000, name: 'UserOrganizationMemberships1731400000000' },
  { timestamp: 1731500000000, name: 'ChatLastReadTimestamps1731500000000' },
  { timestamp: 1731600000000, name: 'ServiceCatalog1731600000000' },
  { timestamp: 1731650000000, name: 'ServiceCatalogSuggestionReview1731650000000' },
  { timestamp: 1731700000000, name: 'ServiceCatalogCategorySort1731700000000' },
  { timestamp: 1731800000000, name: 'SupportChatMessageMeta1731800000000' },
  { timestamp: 1731810000000, name: 'BackfillSupportOperatorMessageType1731810000000' },
  { timestamp: 1731900000000, name: 'UserNotificationPreferences1731900000000' },
  { timestamp: 1732000000000, name: 'OrganizationBusinessKind1732000000000' },
  { timestamp: 1732100000000, name: 'PushDeviceFcmApp1732100000000' },
  { timestamp: 1732200000000, name: 'ServiceCatalogAllowedKindsOrgScheduling1732200000000' },
  { timestamp: 1732300000000, name: 'OrderBayId1732300000000' },
  { timestamp: 1732400000000, name: 'OrderFirstConfirmedAtAndSubscriptionPlanKey1732400000000' },
  { timestamp: 1732500000000, name: 'MediaAssetsAndOrderMedia1732500000000' },
  { timestamp: 1732600000000, name: 'ChatAttachmentsAndMediaChatId1732600000000' },
  { timestamp: 1732700000000, name: 'OrganizationSubscriptionLimitsOverride1732700000000' },
  { timestamp: 1732800000000, name: 'ServiceCatalogExpandByBusinessKind1732800000000' },
  { timestamp: 1732900000000, name: 'AuthSecurityFoundation1732900000000' },
  { timestamp: 1733000000000, name: 'EmailOtpRecipientAndNullablePhone1733000000000' },
  { timestamp: 1733100000000, name: 'OrganizationInvitations1733100000000' },
  { timestamp: 1733200000000, name: 'UserAccountRealm1733200000000' },
  { timestamp: 1733300000000, name: 'OrderCarPhotoUrl1733300000000' },
];

async function main() {
  const url = process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/mp_servis';
  const reset = process.env.DB_BOOTSTRAP_RESET === '1' || process.env.DB_BOOTSTRAP_RESET === 'true';

  const base = {
    type: 'postgres' as const,
    url,
    entities: [entitiesGlob()],
    logging: process.env.NODE_ENV === 'development',
  };

  if (reset) {
    const dsBare = new DataSource({ ...base, synchronize: false });
    await dsBare.initialize();
    const qr0 = dsBare.createQueryRunner();
    await qr0.connect();
    await qr0.query(`DROP SCHEMA IF EXISTS public CASCADE`);
    await qr0.query(`CREATE SCHEMA public`);
    await qr0.query(`GRANT ALL ON SCHEMA public TO PUBLIC`);
    await qr0.query(`GRANT ALL ON SCHEMA public TO CURRENT_USER`);
    await qr0.release();
    await dsBare.destroy();

    const dsSync = new DataSource({ ...base, synchronize: true });
    await dsSync.initialize();
    if (dsSync.entityMetadatas.length === 0) {
      throw new Error(
        'TypeORM не подхватил ни одной сущности (проверьте путь entities в bootstrap-local-schema.ts).',
      );
    }
    await runMigrationsTable(dsSync);
    await dsSync.destroy();
    console.log('[db:bootstrap] Схема public пересоздана (DB_BOOTSTRAP_RESET), таблицы и migrations готовы.');
    return;
  }

  const ds = new DataSource({ ...base, synchronize: true });
  await ds.initialize();
  if (ds.entityMetadatas.length === 0) {
    throw new Error(
      'TypeORM не подхватил ни одной сущности (проверьте путь entities в bootstrap-local-schema.ts).',
    );
  }
  await runMigrationsTable(ds);
  await ds.destroy();
  console.log(
    '[db:bootstrap] Схема синхронизирована по сущностям, в migrations записано',
    APPLIED_MIGRATIONS.length,
    'записей.',
  );
}

async function runMigrationsTable(ds: DataSource) {
  const qr = ds.createQueryRunner();
  await qr.connect();
  await qr.query(`
      CREATE TABLE IF NOT EXISTS "migrations" (
        "id" SERIAL NOT NULL,
        "timestamp" bigint NOT NULL,
        "name" character varying NOT NULL,
        CONSTRAINT "PK_migrations_bootstrap" PRIMARY KEY ("id")
      )
    `);
  await qr.query(`DELETE FROM "migrations"`);
  for (const row of APPLIED_MIGRATIONS) {
    await qr.query(`INSERT INTO "migrations" ("timestamp", "name") VALUES ($1, $2)`, [row.timestamp, row.name]);
  }
  await qr.release();
}

main().catch((e) => {
  console.error('[db:bootstrap]', e.message || e);
  process.exit(1);
});
