import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Биллинговый учёт: первый выход заказа из pending_confirmation в confirmed/in_progress.
 * Тариф: ключ плана подписки организации.
 */
export class OrderFirstConfirmedAtAndSubscriptionPlanKey1732400000000 implements MigrationInterface {
  name = 'OrderFirstConfirmedAtAndSubscriptionPlanKey1732400000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "orders"
      ADD COLUMN IF NOT EXISTS "first_confirmed_at" TIMESTAMPTZ NULL
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_orders_org_first_confirmed_at"
      ON "orders" ("organization_id", "first_confirmed_at")
    `);

    await queryRunner.query(`
      ALTER TABLE "organization_subscriptions"
      ADD COLUMN IF NOT EXISTS "plan_key" varchar(32) NOT NULL DEFAULT 'team'
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_orders_org_first_confirmed_at"`);
    await queryRunner.query(`ALTER TABLE "orders" DROP COLUMN IF EXISTS "first_confirmed_at"`);
    await queryRunner.query(`ALTER TABLE "organization_subscriptions" DROP COLUMN IF EXISTS "plan_key"`);
  }
}
