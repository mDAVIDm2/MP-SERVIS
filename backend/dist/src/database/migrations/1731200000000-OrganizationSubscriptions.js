"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.OrganizationSubscriptions1731200000000 = void 0;
class OrganizationSubscriptions1731200000000 {
    constructor() {
        this.name = 'OrganizationSubscriptions1731200000000';
    }
    async up(queryRunner) {
        await queryRunner.query(`DROP TABLE IF EXISTS "organization_subscriptions" CASCADE`);
        await queryRunner.query(`
      CREATE TABLE "organization_subscriptions" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "organization_id" uuid NOT NULL,
        "start_date" date NOT NULL,
        "end_date" date NOT NULL,
        "is_active" boolean NOT NULL DEFAULT true,
        "status" varchar(32) NOT NULL DEFAULT 'active',
        CONSTRAINT "PK_organization_subscriptions" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_organization_subscriptions_org" UNIQUE ("organization_id"),
        CONSTRAINT "FK_organization_subscriptions_organization" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE CASCADE
      )
    `);
        await queryRunner.query(`
      INSERT INTO organization_subscriptions (id, organization_id, start_date, end_date, is_active, status)
      SELECT uuid_generate_v4(), o.id, CURRENT_DATE, (CURRENT_DATE + INTERVAL '1 year')::date, true, 'active'
      FROM organizations o
      WHERE NOT EXISTS (SELECT 1 FROM organization_subscriptions s WHERE s.organization_id = o.id)
    `).catch(() => { });
    }
    async down(queryRunner) {
        await queryRunner.query(`DROP TABLE IF EXISTS "organization_subscriptions"`);
    }
}
exports.OrganizationSubscriptions1731200000000 = OrganizationSubscriptions1731200000000;
//# sourceMappingURL=1731200000000-OrganizationSubscriptions.js.map