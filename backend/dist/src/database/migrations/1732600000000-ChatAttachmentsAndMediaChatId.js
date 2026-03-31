"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ChatAttachmentsAndMediaChatId1732600000000 = void 0;
class ChatAttachmentsAndMediaChatId1732600000000 {
    constructor() {
        this.name = 'ChatAttachmentsAndMediaChatId1732600000000';
    }
    async up(queryRunner) {
        await queryRunner.query(`ALTER TABLE "media_assets" ALTER COLUMN "organization_id" DROP NOT NULL`);
        await queryRunner.query(`
      ALTER TABLE "media_assets"
      ADD COLUMN IF NOT EXISTS "chat_id" uuid NULL
    `);
        await queryRunner.query(`
      ALTER TABLE "media_assets"
      ADD CONSTRAINT "FK_media_assets_chat"
      FOREIGN KEY ("chat_id") REFERENCES "chats"("id") ON DELETE CASCADE
    `);
        await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_media_assets_chat_id" ON "media_assets" ("chat_id")`);
        await queryRunner.query(`
      CREATE TABLE "chat_message_attachments" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "message_id" uuid NOT NULL,
        "media_asset_id" uuid NOT NULL,
        "sort_order" int NOT NULL DEFAULT 0,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_chat_message_attachments" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_chat_message_attachments_asset" UNIQUE ("media_asset_id"),
        CONSTRAINT "FK_cma_message" FOREIGN KEY ("message_id") REFERENCES "chat_messages"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_cma_asset" FOREIGN KEY ("media_asset_id") REFERENCES "media_assets"("id") ON DELETE CASCADE
      )
    `);
        await queryRunner.query(`CREATE INDEX "IDX_chat_message_attachments_message_id" ON "chat_message_attachments" ("message_id")`);
    }
    async down(queryRunner) {
        await queryRunner.query(`DROP TABLE IF EXISTS "chat_message_attachments"`);
        await queryRunner.query(`ALTER TABLE "media_assets" DROP CONSTRAINT IF EXISTS "FK_media_assets_chat"`);
        await queryRunner.query(`DROP INDEX IF EXISTS "IDX_media_assets_chat_id"`);
        await queryRunner.query(`ALTER TABLE "media_assets" DROP COLUMN IF EXISTS "chat_id"`);
    }
}
exports.ChatAttachmentsAndMediaChatId1732600000000 = ChatAttachmentsAndMediaChatId1732600000000;
//# sourceMappingURL=1732600000000-ChatAttachmentsAndMediaChatId.js.map