import { MigrationInterface, QueryRunner } from 'typeorm';

export class SupportChatMessageMeta1731800000000 implements MigrationInterface {
  name = 'SupportChatMessageMeta1731800000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
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

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "chats" DROP COLUMN IF EXISTS "internal_support_last_read_at"`);
    await queryRunner.query(`ALTER TABLE "chat_messages" DROP COLUMN IF EXISTS "support_channel"`);
    await queryRunner.query(`ALTER TABLE "chat_messages" DROP COLUMN IF EXISTS "is_from_support_operator"`);
  }
}
