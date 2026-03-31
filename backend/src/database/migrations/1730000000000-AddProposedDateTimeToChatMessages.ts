import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddProposedDateTimeToChatMessages1730000000000 implements MigrationInterface {
  name = 'AddProposedDateTimeToChatMessages1730000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "chat_messages"
      ADD COLUMN IF NOT EXISTS "proposed_date_time" TIMESTAMP WITH TIME ZONE NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "chat_messages"
      DROP COLUMN IF EXISTS "proposed_date_time"
    `);
  }
}
