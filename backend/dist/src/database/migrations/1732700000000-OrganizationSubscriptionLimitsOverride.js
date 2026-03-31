"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.OrganizationSubscriptionLimitsOverride1732700000000 = void 0;
class OrganizationSubscriptionLimitsOverride1732700000000 {
    constructor() {
        this.name = 'OrganizationSubscriptionLimitsOverride1732700000000';
    }
    async up(queryRunner) {
        await queryRunner.query(`
      ALTER TABLE "organization_subscriptions"
      ADD COLUMN IF NOT EXISTS "limits_override" jsonb NULL
    `);
    }
    async down(queryRunner) {
        await queryRunner.query(`
      ALTER TABLE "organization_subscriptions" DROP COLUMN IF EXISTS "limits_override"
    `);
    }
}
exports.OrganizationSubscriptionLimitsOverride1732700000000 = OrganizationSubscriptionLimitsOverride1732700000000;
//# sourceMappingURL=1732700000000-OrganizationSubscriptionLimitsOverride.js.map