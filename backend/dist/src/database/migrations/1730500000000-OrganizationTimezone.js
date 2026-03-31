"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.OrganizationTimezone1730500000000 = void 0;
class OrganizationTimezone1730500000000 {
    constructor() {
        this.name = 'OrganizationTimezone1730500000000';
    }
    async up(queryRunner) {
        await queryRunner.query(`
      ALTER TABLE "organizations"
      ADD COLUMN IF NOT EXISTS "timezone" varchar(64) NOT NULL DEFAULT 'Europe/Moscow'
    `);
    }
    async down(queryRunner) {
        await queryRunner.query(`ALTER TABLE "organizations" DROP COLUMN IF EXISTS "timezone"`);
    }
}
exports.OrganizationTimezone1730500000000 = OrganizationTimezone1730500000000;
//# sourceMappingURL=1730500000000-OrganizationTimezone.js.map