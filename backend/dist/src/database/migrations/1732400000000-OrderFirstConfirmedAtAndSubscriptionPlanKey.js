"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.OrderFirstConfirmedAtAndSubscriptionPlanKey1732400000000 = void 0;
class OrderFirstConfirmedAtAndSubscriptionPlanKey1732400000000 {
    constructor() {
        this.name = 'OrderFirstConfirmedAtAndSubscriptionPlanKey1732400000000';
    }
    async up(queryRunner) {
        await queryRunner.query(`
      ALTER TABLE "orders"
      ADD COLUMN IF NOT EXISTS "first_confirmed_at" TIMESTAMPTZ NULL
    `);
        await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_orders_org_first_confirmed_at"
      ON "orders" ("organization_id", "first_confirmed_at")
    `);
        await queryRunner.query(`
      ALTER TABLE "organization_subscriptions"
      ADD COLUMN IF NOT EXISTS "plan_key" varchar(32) NOT NULL DEFAULT 'team'
    `);
    }
    async down(queryRunner) {
        await queryRunner.query(`DROP INDEX IF EXISTS "IDX_orders_org_first_confirmed_at"`);
        await queryRunner.query(`ALTER TABLE "orders" DROP COLUMN IF EXISTS "first_confirmed_at"`);
        await queryRunner.query(`ALTER TABLE "organization_subscriptions" DROP COLUMN IF EXISTS "plan_key"`);
    }
}
exports.OrderFirstConfirmedAtAndSubscriptionPlanKey1732400000000 = OrderFirstConfirmedAtAndSubscriptionPlanKey1732400000000;
//# sourceMappingURL=1732400000000-OrderFirstConfirmedAtAndSubscriptionPlanKey.js.map