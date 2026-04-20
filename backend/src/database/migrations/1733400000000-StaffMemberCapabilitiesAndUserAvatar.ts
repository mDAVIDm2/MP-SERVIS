import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Ранее лежало в backend/migrations/*.sql и scripts/add-*.js.
 * Идемпотентно: безопасно, если колонки уже добавлены вручную.
 */
export class StaffMemberCapabilitiesAndUserAvatar1733400000000 implements MigrationInterface {
  name = 'StaffMemberCapabilitiesAndUserAvatar1733400000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE staff_members
        ADD COLUMN IF NOT EXISTS can_see_chats boolean NOT NULL DEFAULT false,
        ADD COLUMN IF NOT EXISTS can_write_chats boolean NOT NULL DEFAULT false,
        ADD COLUMN IF NOT EXISTS can_manage_org_settings boolean NOT NULL DEFAULT false
    `);
    await queryRunner.query(`
      UPDATE staff_members SET
        can_see_chats = false,
        can_write_chats = false,
        can_manage_org_settings = false
      WHERE role = 'master'
    `);
    await queryRunner.query(`
      UPDATE staff_members SET
        can_see_chats = true,
        can_write_chats = true,
        can_manage_org_settings = true
      WHERE role = 'admin'
    `);
    await queryRunner.query(`
      ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url varchar(1024) NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE users DROP COLUMN IF EXISTS avatar_url`);
    await queryRunner.query(`ALTER TABLE staff_members DROP COLUMN IF EXISTS can_manage_org_settings`);
    await queryRunner.query(`ALTER TABLE staff_members DROP COLUMN IF EXISTS can_write_chats`);
    await queryRunner.query(`ALTER TABLE staff_members DROP COLUMN IF EXISTS can_see_chats`);
  }
}
