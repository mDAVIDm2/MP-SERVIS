import { MigrationInterface, QueryRunner } from 'typeorm';

export class ChatLastReadTimestamps1731500000000 implements MigrationInterface {
  name = 'ChatLastReadTimestamps1731500000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "chats"
      ADD COLUMN IF NOT EXISTS "client_last_read_at" TIMESTAMPTZ NULL
    `);
    await queryRunner.query(`
      ALTER TABLE "chats"
      ADD COLUMN IF NOT EXISTS "organization_last_read_at" TIMESTAMPTZ NULL
    `);
    // Существующие чаты не засыпаем «ложными» непрочитанными: считаем, что обе стороны уже «на текущем моменте».
    await queryRunner.query(`
      UPDATE "chats"
      SET "client_last_read_at" = NOW(), "organization_last_read_at" = NOW()
      WHERE "client_last_read_at" IS NULL AND "organization_last_read_at" IS NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "chats" DROP COLUMN IF EXISTS "organization_last_read_at"`);
    await queryRunner.query(`ALTER TABLE "chats" DROP COLUMN IF EXISTS "client_last_read_at"`);
  }
}
