"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.OrderBayId1732300000000 = void 0;
class OrderBayId1732300000000 {
    constructor() {
        this.name = 'OrderBayId1732300000000';
    }
    async up(queryRunner) {
        await queryRunner.query(`ALTER TABLE "orders" ADD COLUMN IF NOT EXISTS "bay_id" character varying(64)`);
    }
    async down(queryRunner) {
        await queryRunner.query(`ALTER TABLE "orders" DROP COLUMN IF EXISTS "bay_id"`);
    }
}
exports.OrderBayId1732300000000 = OrderBayId1732300000000;
//# sourceMappingURL=1732300000000-OrderBayId.js.map