import { MigrationInterface, QueryRunner } from 'typeorm';

export class NotificationsTable1731300000000 implements MigrationInterface {
  name = 'NotificationsTable1731300000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "notifications" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "user_id" varchar(64) NOT NULL,
        "car_id" varchar(64) NULL,
        "type" varchar(64) NOT NULL,
        "title" varchar(256) NOT NULL,
        "body" text NULL,
        "is_read" boolean NOT NULL DEFAULT false,
        "payload" jsonb NULL,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_notifications" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_notifications_user_id" ON "notifications" ("user_id")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_notifications_car_id" ON "notifications" ("car_id")`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_notifications_is_read" ON "notifications" ("is_read")`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "notifications"`);
  }
}
