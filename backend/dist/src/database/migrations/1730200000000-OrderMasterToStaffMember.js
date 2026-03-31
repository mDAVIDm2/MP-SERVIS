"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.OrderMasterToStaffMember1730200000000 = void 0;
class OrderMasterToStaffMember1730200000000 {
    constructor() {
        this.name = 'OrderMasterToStaffMember1730200000000';
    }
    async up(queryRunner) {
        await queryRunner.query(`ALTER TABLE "orders" DROP CONSTRAINT IF EXISTS "FK_6373fc0c675837fe8dafab8c075"`);
        await queryRunner.query(`UPDATE "orders" SET "master_id" = NULL WHERE "master_id" IS NOT NULL AND "master_id" NOT IN (SELECT "id" FROM "staff_members")`);
        await queryRunner.query(`ALTER TABLE "orders" ADD CONSTRAINT "FK_orders_master_staff" ` +
            `FOREIGN KEY ("master_id") REFERENCES "staff_members"("id") ON DELETE SET NULL`);
    }
    async down(queryRunner) {
        await queryRunner.query(`ALTER TABLE "orders" DROP CONSTRAINT IF EXISTS "FK_orders_master_staff"`);
        await queryRunner.query(`ALTER TABLE "orders" ADD CONSTRAINT "FK_6373fc0c675837fe8dafab8c075" ` +
            `FOREIGN KEY ("master_id") REFERENCES "users"("id") ON DELETE SET NULL`);
    }
}
exports.OrderMasterToStaffMember1730200000000 = OrderMasterToStaffMember1730200000000;
//# sourceMappingURL=1730200000000-OrderMasterToStaffMember.js.map