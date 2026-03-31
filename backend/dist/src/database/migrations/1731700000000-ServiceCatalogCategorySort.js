"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ServiceCatalogCategorySort1731700000000 = void 0;
class ServiceCatalogCategorySort1731700000000 {
    constructor() {
        this.name = 'ServiceCatalogCategorySort1731700000000';
    }
    async up(queryRunner) {
        await queryRunner.query(`
      ALTER TABLE "service_catalog_items"
      ADD COLUMN IF NOT EXISTS "category_sort_order" int NOT NULL DEFAULT 0
    `);
        await queryRunner.query(`
      UPDATE "service_catalog_items" SET "category_sort_order" = 10 WHERE "category_key" = 'maintenance'
    `);
        await queryRunner.query(`
      UPDATE "service_catalog_items" SET "category_sort_order" = 20 WHERE "category_key" = 'engine'
    `);
        await queryRunner.query(`
      UPDATE "service_catalog_items" SET "category_sort_order" = 30 WHERE "category_key" = 'suspension'
    `);
        await queryRunner.query(`
      UPDATE "service_catalog_items" SET "category_sort_order" = 40 WHERE "category_key" = 'brakes'
    `);
        await queryRunner.query(`
      UPDATE "service_catalog_items" SET "category_sort_order" = 50 WHERE "category_key" = 'electrical'
    `);
        await queryRunner.query(`
      UPDATE "service_catalog_items" SET "category_sort_order" = 60 WHERE "category_key" = 'tires'
    `);
        await queryRunner.query(`
      UPDATE "service_catalog_items" SET "category_sort_order" = 70 WHERE "category_key" = 'body'
    `);
        await queryRunner.query(`
      UPDATE "service_catalog_items" SET "category_sort_order" = 80 WHERE "category_key" = 'diagnostics'
    `);
    }
    async down(queryRunner) {
        await queryRunner.query(`ALTER TABLE "service_catalog_items" DROP COLUMN IF EXISTS "category_sort_order"`);
    }
}
exports.ServiceCatalogCategorySort1731700000000 = ServiceCatalogCategorySort1731700000000;
//# sourceMappingURL=1731700000000-ServiceCatalogCategorySort.js.map