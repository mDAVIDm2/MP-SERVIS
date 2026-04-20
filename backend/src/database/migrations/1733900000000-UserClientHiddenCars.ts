import { MigrationInterface, QueryRunner } from 'typeorm';

export class UserClientHiddenCars1733900000000 implements MigrationInterface {
  name = 'UserClientHiddenCars1733900000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "user_client_hidden_cars" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "user_id" uuid NOT NULL,
        "car_id" varchar(64) NOT NULL,
        "hidden_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_user_client_hidden_cars" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_user_client_hidden_cars_user_car" UNIQUE ("user_id", "car_id")
      )
    `);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_user_client_hidden_cars_user" ON "user_client_hidden_cars" ("user_id")`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "user_client_hidden_cars"`);
  }
}
