"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ChatLastReadTimestamps1731500000000 = void 0;
class ChatLastReadTimestamps1731500000000 {
    constructor() {
        this.name = 'ChatLastReadTimestamps1731500000000';
    }
    async up(queryRunner) {
        await queryRunner.query(`
      ALTER TABLE "chats"
      ADD COLUMN IF NOT EXISTS "client_last_read_at" TIMESTAMPTZ NULL
    `);
        await queryRunner.query(`
      ALTER TABLE "chats"
      ADD COLUMN IF NOT EXISTS "organization_last_read_at" TIMESTAMPTZ NULL
    `);
        await queryRunner.query(`
      UPDATE "chats"
      SET "client_last_read_at" = NOW(), "organization_last_read_at" = NOW()
      WHERE "client_last_read_at" IS NULL AND "organization_last_read_at" IS NULL
    `);
    }
    async down(queryRunner) {
        await queryRunner.query(`ALTER TABLE "chats" DROP COLUMN IF EXISTS "organization_last_read_at"`);
        await queryRunner.query(`ALTER TABLE "chats" DROP COLUMN IF EXISTS "client_last_read_at"`);
    }
}
exports.ChatLastReadTimestamps1731500000000 = ChatLastReadTimestamps1731500000000;
//# sourceMappingURL=1731500000000-ChatLastReadTimestamps.js.map