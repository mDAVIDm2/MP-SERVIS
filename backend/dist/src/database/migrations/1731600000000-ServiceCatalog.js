"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ServiceCatalog1731600000000 = void 0;
class ServiceCatalog1731600000000 {
    constructor() {
        this.name = 'ServiceCatalog1731600000000';
    }
    async up(queryRunner) {
        await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "service_catalog_items" (
        "id" varchar(96) NOT NULL,
        "category_key" varchar(64) NOT NULL,
        "category_name" varchar(160) NOT NULL,
        "name" varchar(512) NOT NULL,
        "default_duration_minutes" int NOT NULL DEFAULT 60,
        "sort_order" int NOT NULL DEFAULT 0,
        "required_skill" varchar(32) NULL,
        CONSTRAINT "PK_service_catalog_items" PRIMARY KEY ("id")
      )
    `);
        await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_service_catalog_category" ON "service_catalog_items" ("category_key", "sort_order")`);
        await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "service_catalog_suggestions" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "organization_id" uuid NOT NULL,
        "requested_name" varchar(512) NOT NULL,
        "category_hint" varchar(256) NULL,
        "note" text NULL,
        "status" varchar(32) NOT NULL DEFAULT 'pending',
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_service_catalog_suggestions" PRIMARY KEY ("id"),
        CONSTRAINT "FK_scs_organization" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE CASCADE
      )
    `);
        await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_scs_org_created" ON "service_catalog_suggestions" ("organization_id", "created_at")`);
    }
    async down(queryRunner) {
        await queryRunner.query(`DROP TABLE IF EXISTS "service_catalog_suggestions"`);
        await queryRunner.query(`DROP TABLE IF EXISTS "service_catalog_items"`);
    }
}
exports.ServiceCatalog1731600000000 = ServiceCatalog1731600000000;
//# sourceMappingURL=1731600000000-ServiceCatalog.js.map