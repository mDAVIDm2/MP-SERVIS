import { MigrationInterface, QueryRunner } from 'typeorm';

export class OrderCarPhotoUrl1733300000000 implements MigrationInterface {
  name = 'OrderCarPhotoUrl1733300000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "orders" ADD COLUMN IF NOT EXISTS "car_photo_url" character varying(1024)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "orders" DROP COLUMN IF EXISTS "car_photo_url"`);
  }
}
