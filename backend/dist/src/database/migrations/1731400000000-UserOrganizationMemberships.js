"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.UserOrganizationMemberships1731400000000 = void 0;
class UserOrganizationMemberships1731400000000 {
    constructor() {
        this.name = 'UserOrganizationMemberships1731400000000';
    }
    async up(queryRunner) {
        await queryRunner.query(`
      CREATE TABLE "user_organization_memberships" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "user_id" uuid NOT NULL,
        "organization_id" uuid NOT NULL,
        "role" varchar(20) NOT NULL DEFAULT 'owner',
        CONSTRAINT "PK_user_organization_memberships" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_user_org_membership" UNIQUE ("user_id", "organization_id"),
        CONSTRAINT "FK_uom_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_uom_organization" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE CASCADE
      )
    `);
        await queryRunner.query(`CREATE INDEX "IDX_user_org_membership_user" ON "user_organization_memberships" ("user_id")`);
        await queryRunner.query(`CREATE INDEX "IDX_user_org_membership_org" ON "user_organization_memberships" ("organization_id")`);
        await queryRunner.query(`
      INSERT INTO user_organization_memberships (id, user_id, organization_id, role)
      SELECT uuid_generate_v4(), u.id, u.organization_id, u.role
      FROM users u
      WHERE u.organization_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM user_organization_memberships m
        WHERE m.user_id = u.id AND m.organization_id = u.organization_id
      )
    `);
    }
    async down(queryRunner) {
        await queryRunner.query(`DROP TABLE IF EXISTS "user_organization_memberships"`);
    }
}
exports.UserOrganizationMemberships1731400000000 = UserOrganizationMemberships1731400000000;
//# sourceMappingURL=1731400000000-UserOrganizationMemberships.js.map