import { MigrationInterface, QueryRunner } from 'typeorm';

export class ClientCars1733600000000 implements MigrationInterface {
  name = 'ClientCars1733600000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "client_cars" (
        "id" character varying(64) NOT NULL,
        "user_id" uuid NOT NULL,
        "brand" character varying NOT NULL DEFAULT '',
        "model" character varying NOT NULL DEFAULT '',
        "generation" character varying(256),
        "brand_id" integer,
        "model_id" integer,
        "generation_id" integer,
        "year" integer NOT NULL DEFAULT 0,
        "nickname" character varying(128),
        "plate_number" character varying(32),
        "vin" character varying(32),
        "mileage" integer NOT NULL DEFAULT 0,
        "engine_type" character varying(64),
        "transmission" character varying(64),
        "drivetrain" character varying(64),
        "body_type" character varying(64),
        "color" character varying(64),
        "photo_url" character varying(1024),
        "merged_from_orders" boolean NOT NULL DEFAULT false,
        "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
        CONSTRAINT "PK_client_cars" PRIMARY KEY ("id"),
        CONSTRAINT "FK_client_cars_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_client_cars_user_id" ON "client_cars" ("user_id")`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "client_cars"`);
  }
}
