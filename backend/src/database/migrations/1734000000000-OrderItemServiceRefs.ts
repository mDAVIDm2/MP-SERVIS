import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Ссылки на строку прайса организации и на позицию общего каталога (без изменения цены/времени в строке —
 * они по-прежнему фактические для заказа).
 */
export class OrderItemServiceRefs1734000000000 implements MigrationInterface {
  name = 'OrderItemServiceRefs1734000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "order_items"
      ADD COLUMN IF NOT EXISTS "organization_service_id" character varying(64) NULL
    `);
    await queryRunner.query(`
      ALTER TABLE "order_items"
      ADD COLUMN IF NOT EXISTS "catalog_item_id" character varying(128) NULL
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_order_items_org_service"
      ON "order_items" ("organization_service_id")
      WHERE "organization_service_id" IS NOT NULL
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_order_items_catalog_item"
      ON "order_items" ("catalog_item_id")
      WHERE "catalog_item_id" IS NOT NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_order_items_catalog_item"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_order_items_org_service"`);
    await queryRunner.query(`ALTER TABLE "order_items" DROP COLUMN IF EXISTS "catalog_item_id"`);
    await queryRunner.query(`ALTER TABLE "order_items" DROP COLUMN IF EXISTS "organization_service_id"`);
  }
}
