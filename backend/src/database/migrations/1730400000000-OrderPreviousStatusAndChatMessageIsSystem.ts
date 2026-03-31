import { MigrationInterface, QueryRunner } from 'typeorm';

export class OrderPreviousStatusAndChatMessageIsSystem1730400000000 implements MigrationInterface {
  name = 'OrderPreviousStatusAndChatMessageIsSystem1730400000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "orders"
      ADD COLUMN IF NOT EXISTS "previous_status" VARCHAR(30) NULL
    `);
    await queryRunner.query(`
      ALTER TABLE "chat_messages"
      ADD COLUMN IF NOT EXISTS "is_system" BOOLEAN NOT NULL DEFAULT false
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
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
