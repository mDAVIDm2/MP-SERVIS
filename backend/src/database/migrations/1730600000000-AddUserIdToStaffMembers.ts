import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Добавляем user_id в staff_members: привязка к пользователю (владелец/админ как мастер).
 */
export class AddUserIdToStaffMembers1730600000000 implements MigrationInterface {
  name = 'AddUserIdToStaffMembers1730600000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "staff_members" ADD COLUMN IF NOT EXISTS "user_id" uuid REFERENCES "users"("id") ON DELETE SET NULL`,
    );
    await queryRunner.query(
      `CREATE UNIQUE INDEX IF NOT EXISTS "IDX_staff_members_org_user" ON "staff_members" ("organization_id", "user_id") WHERE "user_id" IS NOT NULL`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_staff_members_org_user"`);
    await queryRunner.query(`ALTER TABLE "staff_members" DROP COLUMN IF EXISTS "user_id"`);
  }
}
