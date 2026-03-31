"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AddUserIdToStaffMembers1730600000000 = void 0;
class AddUserIdToStaffMembers1730600000000 {
    constructor() {
        this.name = 'AddUserIdToStaffMembers1730600000000';
    }
    async up(queryRunner) {
        await queryRunner.query(`ALTER TABLE "staff_members" ADD COLUMN IF NOT EXISTS "user_id" uuid REFERENCES "users"("id") ON DELETE SET NULL`);
        await queryRunner.query(`CREATE UNIQUE INDEX IF NOT EXISTS "IDX_staff_members_org_user" ON "staff_members" ("organization_id", "user_id") WHERE "user_id" IS NOT NULL`);
    }
    async down(queryRunner) {
        await queryRunner.query(`DROP INDEX IF EXISTS "IDX_staff_members_org_user"`);
        await queryRunner.query(`ALTER TABLE "staff_members" DROP COLUMN IF EXISTS "user_id"`);
    }
}
exports.AddUserIdToStaffMembers1730600000000 = AddUserIdToStaffMembers1730600000000;
//# sourceMappingURL=1730600000000-AddUserIdToStaffMembers.js.map