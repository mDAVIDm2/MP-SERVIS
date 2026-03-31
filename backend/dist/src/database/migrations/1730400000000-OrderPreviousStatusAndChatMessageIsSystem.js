"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.OrderPreviousStatusAndChatMessageIsSystem1730400000000 = void 0;
class OrderPreviousStatusAndChatMessageIsSystem1730400000000 {
    constructor() {
        this.name = 'OrderPreviousStatusAndChatMessageIsSystem1730400000000';
    }
    async up(queryRunner) {
        await queryRunner.query(`
      ALTER TABLE "orders"
      ADD COLUMN IF NOT EXISTS "previous_status" VARCHAR(30) NULL
    `);
        await queryRunner.query(`
      ALTER TABLE "chat_messages"
      ADD COLUMN IF NOT EXISTS "is_system" BOOLEAN NOT NULL DEFAULT false
    `);
    }
    async down(queryRunner) {
        await queryRunner.query(`
      ALTER TABLE "orders"
      DROP COLUMN IF EXISTS "previous_status"
    `);
        await queryRunner.query(`
      ALTER TABLE "chat_messages"
      DROP COLUMN IF EXISTS "is_system"
    `);
    }
}
exports.OrderPreviousStatusAndChatMessageIsSystem1730400000000 = OrderPreviousStatusAndChatMessageIsSystem1730400000000;
//# sourceMappingURL=1730400000000-OrderPreviousStatusAndChatMessageIsSystem.js.map