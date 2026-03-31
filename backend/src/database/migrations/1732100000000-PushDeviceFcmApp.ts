import { MigrationInterface, QueryRunner } from 'typeorm';

/** Какой Firebase-проект выдал FCM-токен (клиент mp-servis-31b40 vs СТО mp-servis-bissnes). */
export class PushDeviceFcmApp1732100000000 implements MigrationInterface {
  name = 'PushDeviceFcmApp1732100000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "push_devices"
      ADD COLUMN IF NOT EXISTS "fcm_app" varchar(16) NOT NULL DEFAULT 'client'
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "push_devices" DROP COLUMN IF EXISTS "fcm_app"`);
  }
}
