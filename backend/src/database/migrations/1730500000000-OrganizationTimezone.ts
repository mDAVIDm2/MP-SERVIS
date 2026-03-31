import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Часовой пояс организации для мультитенантности: слоты и рабочее время считаются в локальном времени СТО.
 */
export class OrganizationTimezone1730500000000 implements MigrationInterface {
  name = 'OrganizationTimezone1730500000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "organizations"
      ADD COLUMN IF NOT EXISTS "timezone" varchar(64) NOT NULL DEFAULT 'Europe/Moscow'
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "organizations" DROP COLUMN IF EXISTS "timezone"`);
  }
}
