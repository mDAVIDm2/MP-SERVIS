"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ServiceCatalogAllowedKindsOrgScheduling1732200000000 = void 0;
class ServiceCatalogAllowedKindsOrgScheduling1732200000000 {
    constructor() {
        this.name = 'ServiceCatalogAllowedKindsOrgScheduling1732200000000';
    }
    async up(queryRunner) {
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
    async down(queryRunner) {
        await queryRunner.query(`ALTER TABLE "service_catalog_items" DROP COLUMN IF EXISTS "allowed_business_kinds"`);
        await queryRunner.query(`ALTER TABLE "organizations" DROP COLUMN IF EXISTS "scheduling_mode"`);
    }
}
exports.ServiceCatalogAllowedKindsOrgScheduling1732200000000 = ServiceCatalogAllowedKindsOrgScheduling1732200000000;
//# sourceMappingURL=1732200000000-ServiceCatalogAllowedKindsOrgScheduling.js.map