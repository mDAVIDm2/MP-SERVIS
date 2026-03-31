import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Справочник услуг: каким типам организаций доступна позиция.
 * Организации: режим записи (к мастеру или на пост).
 */
export class ServiceCatalogAllowedKindsOrgScheduling1732200000000 implements MigrationInterface {
  name = 'ServiceCatalogAllowedKindsOrgScheduling1732200000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "organizations"
      ADD COLUMN IF NOT EXISTS "scheduling_mode" varchar(16) NOT NULL DEFAULT 'staff_based'
    `);

    await queryRunner.query(`
      UPDATE "organizations"
      SET "scheduling_mode" = 'bay_based'
      WHERE "business_kind" IN ('car_wash', 'tire_service', 'detailing', 'body_shop')
    `);

    await queryRunner.query(`
      ALTER TABLE "service_catalog_items"
      ADD COLUMN IF NOT EXISTS "allowed_business_kinds" jsonb NOT NULL DEFAULT '["sto"]'
    `);

    await queryRunner.query(`
      UPDATE "service_catalog_items" SET "allowed_business_kinds" = '["sto","tuning","ev_service","other"]'::jsonb
      WHERE "category_key" IN ('maintenance', 'engine', 'suspension')
    `);
    await queryRunner.query(`
      UPDATE "service_catalog_items" SET "allowed_business_kinds" = '["sto","tire_service","other"]'::jsonb
      WHERE "category_key" = 'brakes'
    `);
    await queryRunner.query(`
      UPDATE "service_catalog_items" SET "allowed_business_kinds" = '["sto","car_audio","ev_service","other"]'::jsonb
      WHERE "category_key" = 'electrical'
    `);
    await queryRunner.query(`
      UPDATE "service_catalog_items" SET "allowed_business_kinds" = '["sto","tire_service","other"]'::jsonb
      WHERE "category_key" = 'tires'
    `);
    await queryRunner.query(`
      UPDATE "service_catalog_items" SET "allowed_business_kinds" = '["sto","body_shop","detailing","glass","other"]'::jsonb
      WHERE "category_key" = 'body'
    `);
    await queryRunner.query(`
      UPDATE "service_catalog_items" SET "allowed_business_kinds" = '["sto","tire_service","ev_service","other"]'::jsonb
      WHERE "category_key" = 'diagnostics'
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "service_catalog_items" DROP COLUMN IF EXISTS "allowed_business_kinds"`);
    await queryRunner.query(`ALTER TABLE "organizations" DROP COLUMN IF EXISTS "scheduling_mode"`);
  }
}
