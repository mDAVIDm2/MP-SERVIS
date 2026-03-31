import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Тип организации (СТО, мойка, детейлинг и т.д.) — для отображения в клиентском приложении (например подпись в чате).
 */
export class OrganizationBusinessKind1732000000000 implements MigrationInterface {
  name = 'OrganizationBusinessKind1732000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "organizations"
      ADD COLUMN IF NOT EXISTS "business_kind" varchar(32) NOT NULL DEFAULT 'sto'
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "organizations" DROP COLUMN IF EXISTS "business_kind"`);
  }
}
