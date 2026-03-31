"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SupportChatMessageMeta1731800000000 = void 0;
class SupportChatMessageMeta1731800000000 {
    constructor() {
        this.name = 'SupportChatMessageMeta1731800000000';
    }
    async up(queryRunner) {
        await queryRunner.query(`
      ALTER TABLE "chat_messages"
      ADD COLUMN IF NOT EXISTS "is_from_support_operator" BOOLEAN NOT NULL DEFAULT false
    `);
        await queryRunner.query(`
      ALTER TABLE "chat_messages"
      ADD COLUMN IF NOT EXISTS "support_channel" VARCHAR(16) NULL
    `);
        await queryRunner.query(`
      ALTER TABLE "chats"
      ADD COLUMN IF NOT EXISTS "internal_support_last_read_at" TIMESTAMPTZ NULL
    `);
    }
    async down(queryRunner) {
        await queryRunner.query(`ALTER TABLE "chats" DROP COLUMN IF EXISTS "internal_support_last_read_at"`);
        await queryRunner.query(`ALTER TABLE "chat_messages" DROP COLUMN IF EXISTS "support_channel"`);
        await queryRunner.query(`ALTER TABLE "chat_messages" DROP COLUMN IF EXISTS "is_from_support_operator"`);
    }
}
exports.SupportChatMessageMeta1731800000000 = SupportChatMessageMeta1731800000000;
//# sourceMappingURL=1731800000000-SupportChatMessageMeta.js.map