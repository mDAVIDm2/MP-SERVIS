"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.OrganizationBusinessKind1732000000000 = void 0;
class OrganizationBusinessKind1732000000000 {
    constructor() {
        this.name = 'OrganizationBusinessKind1732000000000';
    }
    async up(queryRunner) {
        await queryRunner.query(`
      ALTER TABLE "organizations"
      ADD COLUMN IF NOT EXISTS "business_kind" varchar(32) NOT NULL DEFAULT 'sto'
    `);
    }
    async down(queryRunner) {
        await queryRunner.query(`ALTER TABLE "organizations" DROP COLUMN IF EXISTS "business_kind"`);
    }
}
exports.OrganizationBusinessKind1732000000000 = OrganizationBusinessKind1732000000000;
//# sourceMappingURL=1732000000000-OrganizationBusinessKind.js.map