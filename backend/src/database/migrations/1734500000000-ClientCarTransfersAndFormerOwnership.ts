import { MigrationInterface, QueryRunner } from 'typeorm';

export class ClientCarTransfersAndFormerOwnership1734500000000 implements MigrationInterface {
  name = 'ClientCarTransfersAndFormerOwnership1734500000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "client_car_transfers" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "car_id" character varying(64) NOT NULL,
        "from_user_id" uuid NOT NULL,
        "to_user_id" uuid,
        "to_phone_norm" character varying(20) NOT NULL,
        "status" character varying(20) NOT NULL DEFAULT 'pending',
        "options" jsonb,
        "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
        CONSTRAINT "PK_client_car_transfers" PRIMARY KEY ("id"),
        CONSTRAINT "FK_client_car_transfers_car" FOREIGN KEY ("car_id") REFERENCES "client_cars"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_client_car_transfers_from_user" FOREIGN KEY ("from_user_id") REFERENCES "users"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_client_car_transfers_to_user" FOREIGN KEY ("to_user_id") REFERENCES "users"("id") ON DELETE SET NULL
      )
    `);
    await queryRunner.query(
      `CREATE UNIQUE INDEX IF NOT EXISTS "UQ_client_car_transfers_pending_car" ON "client_car_transfers" ("car_id") WHERE "status" = 'pending'`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_client_car_transfers_to_user" ON "client_car_transfers" ("to_user_id")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_client_car_transfers_to_phone" ON "client_car_transfers" ("to_phone_norm")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_client_car_transfers_from_user" ON "client_car_transfers" ("from_user_id")`,
    );

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "client_car_former_ownership" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "user_id" uuid NOT NULL,
        "car_id" character varying(64) NOT NULL,
        "transfer_id" uuid,
        "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
        CONSTRAINT "PK_client_car_former_ownership" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_former_user_car" UNIQUE ("user_id", "car_id"),
        CONSTRAINT "FK_former_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_former_car" FOREIGN KEY ("car_id") REFERENCES "client_cars"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_former_transfer" FOREIGN KEY ("transfer_id") REFERENCES "client_car_transfers"("id") ON DELETE SET NULL
      )
    `);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_former_user_id" ON "client_car_former_ownership" ("user_id")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_former_car_id" ON "client_car_former_ownership" ("car_id")`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "client_car_former_ownership"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "client_car_transfers"`);
  }
}
