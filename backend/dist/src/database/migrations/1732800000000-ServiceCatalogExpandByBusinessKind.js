"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ServiceCatalogExpandByBusinessKind1732800000000 = void 0;
const service_catalog_seed_extra_1 = require("../../reference/service-catalog.seed-extra");
const service_catalog_metadata_1 = require("../../reference/service-catalog-metadata");
class ServiceCatalogExpandByBusinessKind1732800000000 {
    constructor() {
        this.name = 'ServiceCatalogExpandByBusinessKind1732800000000';
    }
    async up(queryRunner) {
        for (const row of service_catalog_seed_extra_1.SERVICE_CATALOG_SEED_EXTRA) {
            const cso = service_catalog_metadata_1.SERVICE_CATALOG_CATEGORY_SORT_ORDER[row.categoryKey] ?? 1000;
            const kinds = JSON.stringify((0, service_catalog_metadata_1.catalogAllowedKindsForCategoryKey)(row.categoryKey));
            await queryRunner.query(`INSERT INTO "service_catalog_items" (
          "id", "category_key", "category_name", "category_sort_order", "name",
          "default_duration_minutes", "sort_order", "required_skill", "allowed_business_kinds"
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::jsonb)
        ON CONFLICT ("id") DO NOTHING`, [
                row.id,
                row.categoryKey,
                row.categoryName,
                cso,
                row.name,
                row.defaultDurationMinutes,
                row.sortOrder,
                row.requiredSkill ?? null,
                kinds,
            ]);
        }
        await queryRunner.query(`
      UPDATE "service_catalog_items"
      SET "allowed_business_kinds" = '["sto","body_shop","detailing","glass","car_wash","other"]'::jsonb
      WHERE "category_key" = 'body'
    `);
        await queryRunner.query(`
      UPDATE "service_catalog_items"
      SET "allowed_business_kinds" = '["sto","tire_service","ev_service","detailing","other"]'::jsonb
      WHERE "category_key" = 'diagnostics'
    `);
    }
    async down(queryRunner) {
        for (const row of service_catalog_seed_extra_1.SERVICE_CATALOG_SEED_EXTRA) {
            await queryRunner.query(`DELETE FROM "service_catalog_items" WHERE "id" = $1`, [row.id]);
        }
        await queryRunner.query(`
      UPDATE "service_catalog_items"
      SET "allowed_business_kinds" = '["sto","body_shop","detailing","glass","other"]'::jsonb
      WHERE "category_key" = 'body'
    `);
        await queryRunner.query(`
      UPDATE "service_catalog_items"
      SET "allowed_business_kinds" = '["sto","tire_service","ev_service","other"]'::jsonb
      WHERE "category_key" = 'diagnostics'
    `);
    }
}
exports.ServiceCatalogExpandByBusinessKind1732800000000 = ServiceCatalogExpandByBusinessKind1732800000000;
//# sourceMappingURL=1732800000000-ServiceCatalogExpandByBusinessKind.js.map