import { MigrationInterface, QueryRunner } from 'typeorm';

export class CarManualExpenses1740300000000 implements MigrationInterface {
  name = 'CarManualExpenses1740300000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "car_manual_expenses" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "user_id" uuid NOT NULL,
        "car_id" character varying(64) NOT NULL,
        "client_local_id" character varying(120) NOT NULL,
        "kind" character varying(40) NOT NULL,
        "date" TIMESTAMPTZ NOT NULL,
        "price_kopecks" integer NOT NULL,
        "fuel_type" character varying(40),
        "liters" numeric(14,4),
        "price_per_liter_kopecks" integer,
        "odometer_km" integer,
        "fuel_station_name" text,
        "full_tank" boolean,
        "preset_id" character varying(100),
        "custom_title" text,
        "note" text,
        "expense_group_id" character varying(100),
        "expense_sub_id" character varying(100),
        "expense_category_id" character varying(100),
        "expense_item_title" character varying(200),
        "analytics_operation_name" character varying(100),
        "material_price_kopecks" integer,
        "labor_price_kopecks" integer,
        "place_name" text,
        "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
        "deleted_at" TIMESTAMPTZ,
        "client_updated_at" TIMESTAMPTZ,
        "device_id" character varying(128),
        "version" integer NOT NULL DEFAULT 1,
        CONSTRAINT "PK_car_manual_expenses" PRIMARY KEY ("id"),
        CONSTRAINT "FK_car_manual_expenses_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_car_manual_expenses_car" FOREIGN KEY ("car_id") REFERENCES "client_cars"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS "UQ_car_manual_expenses_user_car_client_local"
      ON "car_manual_expenses" ("user_id", "car_id", "client_local_id")
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_car_manual_expenses_user_car_date"
      ON "car_manual_expenses" ("user_id", "car_id", "date" DESC)
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_car_manual_expenses_user_car_updated"
      ON "car_manual_expenses" ("user_id", "car_id", "updated_at")
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_car_manual_expenses_user_car_deleted"
      ON "car_manual_expenses" ("user_id", "car_id", "deleted_at")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "car_manual_expenses"`);
  }
}
