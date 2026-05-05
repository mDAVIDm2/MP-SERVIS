import { MigrationInterface, QueryRunner } from 'typeorm';

export class OrganizationWorkingHoursExceptions1735000000000 implements MigrationInterface {
  name = 'OrganizationWorkingHoursExceptions1735000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "organizations"
      ADD COLUMN IF NOT EXISTS "working_hours_exceptions" jsonb NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "organizations" DROP COLUMN IF EXISTS "working_hours_exceptions"`);
  }
}
