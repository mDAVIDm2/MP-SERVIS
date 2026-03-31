"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.OrganizationInvitations1733100000000 = void 0;
class OrganizationInvitations1733100000000 {
    constructor() {
        this.name = 'OrganizationInvitations1733100000000';
    }
    async up(queryRunner) {
        await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "organization_invitations" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "organization_id" uuid NOT NULL,
        "invited_by_user_id" uuid NOT NULL,
        "accepted_by_user_id" uuid NULL,
        "staff_member_id" uuid NULL,
        "role" varchar(20) NOT NULL DEFAULT 'master',
        "invited_name" varchar(255) NULL,
        "invited_email" varchar(320) NULL,
        "invited_email_norm" varchar(320) NULL,
        "invited_phone" varchar(32) NULL,
        "invited_phone_norm" varchar(32) NULL,
        "status" varchar(20) NOT NULL DEFAULT 'pending',
        "message" varchar(500) NULL,
        "expires_at" timestamptz NULL,
        "responded_at" timestamptz NULL,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_organization_invitations" PRIMARY KEY ("id"),
        CONSTRAINT "FK_org_inv_org" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_org_inv_invited_by" FOREIGN KEY ("invited_by_user_id") REFERENCES "users"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_org_inv_accepted_by" FOREIGN KEY ("accepted_by_user_id") REFERENCES "users"("id") ON DELETE SET NULL,
        CONSTRAINT "FK_org_inv_staff" FOREIGN KEY ("staff_member_id") REFERENCES "staff_members"("id") ON DELETE SET NULL
      )
    `);
        await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_org_invites_org" ON "organization_invitations" ("organization_id")`);
        await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_org_invites_pending_email" ON "organization_invitations" ("organization_id", "invited_email_norm", "status")`);
        await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_org_invites_pending_phone" ON "organization_invitations" ("organization_id", "invited_phone_norm", "status")`);
    }
    async down(queryRunner) {
        await queryRunner.query(`DROP INDEX IF EXISTS "IDX_org_invites_pending_phone"`);
        await queryRunner.query(`DROP INDEX IF EXISTS "IDX_org_invites_pending_email"`);
        await queryRunner.query(`DROP INDEX IF EXISTS "IDX_org_invites_org"`);
        await queryRunner.query(`DROP TABLE IF EXISTS "organization_invitations"`);
    }
}
exports.OrganizationInvitations1733100000000 = OrganizationInvitations1733100000000;
//# sourceMappingURL=1733100000000-OrganizationInvitations.js.map