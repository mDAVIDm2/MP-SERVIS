import { MigrationInterface, QueryRunner } from 'typeorm';

export class OrderOrgConfirmedOnBehalfOfClient1734900000000 implements MigrationInterface {
  name = 'OrderOrgConfirmedOnBehalfOfClient1734900000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "orders"
      ADD COLUMN IF NOT EXISTS "org_confirmed_on_behalf_of_client" boolean NOT NULL DEFAULT false
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "orders" DROP COLUMN IF EXISTS "org_confirmed_on_behalf_of_client"`);
  }
}
