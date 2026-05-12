import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Понедельник–воскресенье: open/close (HH:mm) и closed по каждому дню.
 */
export class OrganizationWorkingHoursWeek1734600000000 implements MigrationInterface {
  name = 'OrganizationWorkingHoursWeek1734600000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "organizations"
      ADD COLUMN IF NOT EXISTS "working_hours_week" jsonb NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "organizations" DROP COLUMN IF EXISTS "working_hours_week"`);
  }
}
