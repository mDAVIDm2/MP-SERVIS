"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ServiceCatalogSuggestionReview1731650000000 = void 0;
class ServiceCatalogSuggestionReview1731650000000 {
    constructor() {
        this.name = 'ServiceCatalogSuggestionReview1731650000000';
    }
    async up(queryRunner) {
        await queryRunner.query(`
      ALTER TABLE "service_catalog_suggestions"
      ADD COLUMN IF NOT EXISTS "reviewed_at" TIMESTAMP NULL
    `);
        await queryRunner.query(`
      ALTER TABLE "service_catalog_suggestions"
      ADD COLUMN IF NOT EXISTS "review_note" text NULL
    `);
        await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_scs_status_created" ON "service_catalog_suggestions" ("status", "created_at" DESC)`);
    }
    async down(queryRunner) {
        await queryRunner.query(`DROP INDEX IF EXISTS "IDX_scs_status_created"`);
        await queryRunner.query(`ALTER TABLE "service_catalog_suggestions" DROP COLUMN IF EXISTS "review_note"`);
        await queryRunner.query(`ALTER TABLE "service_catalog_suggestions" DROP COLUMN IF EXISTS "reviewed_at"`);
    }
}
exports.ServiceCatalogSuggestionReview1731650000000 = ServiceCatalogSuggestionReview1731650000000;
//# sourceMappingURL=1731650000000-ServiceCatalogSuggestionReview.js.map