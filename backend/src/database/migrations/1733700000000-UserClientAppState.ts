import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Колонки для UsersService.getClientAppState / putClientAppState.
 * Идемпотентно для продакшена.
 */
export class UserClientAppState1733700000000 implements MigrationInterface {
  name = 'UserClientAppState1733700000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE users
        ADD COLUMN IF NOT EXISTS client_app_state jsonb NULL,
        ADD COLUMN IF NOT EXISTS client_app_state_updated_at timestamptz NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE users DROP COLUMN IF EXISTS client_app_state_updated_at`);
    await queryRunner.query(`ALTER TABLE users DROP COLUMN IF EXISTS client_app_state`);
  }
}
