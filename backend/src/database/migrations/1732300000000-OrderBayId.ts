import { MigrationInterface, QueryRunner } from 'typeorm';

export class OrderBayId1732300000000 implements MigrationInterface {
  name = 'OrderBayId1732300000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "orders" ADD COLUMN IF NOT EXISTS "bay_id" character varying(64)`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "orders" DROP COLUMN IF EXISTS "bay_id"`);
  }
}
