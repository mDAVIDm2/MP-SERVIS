import { MigrationInterface, QueryRunner } from 'typeorm';

export class MediaAssetsAndOrderMedia1732500000000 implements MigrationInterface {
  name = 'MediaAssetsAndOrderMedia1732500000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "media_assets" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "organization_id" uuid NOT NULL,
        "uploaded_by_user_id" uuid NULL,
        "media_type" varchar(16) NOT NULL,
        "mime_type" varchar(128) NOT NULL,
        "storage_provider" varchar(16) NOT NULL DEFAULT 'local',
        "storage_key" varchar(512) NOT NULL,
        "original_filename" varchar(255) NULL,
        "size_bytes" int NOT NULL DEFAULT 0,
        "width" int NULL,
        "height" int NULL,
        "duration_sec" int NULL,
        "status" varchar(16) NOT NULL DEFAULT 'ready',
        "created_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_media_assets" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_media_assets_storage_key" UNIQUE ("storage_key"),
        CONSTRAINT "FK_media_assets_organization" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_media_assets_user" FOREIGN KEY ("uploaded_by_user_id") REFERENCES "users"("id") ON DELETE SET NULL
      )
    `);
    await queryRunner.query(`CREATE INDEX "IDX_media_assets_organization_id" ON "media_assets" ("organization_id")`);

    await queryRunner.query(`
      CREATE TABLE "order_media" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "order_id" uuid NOT NULL,
        "media_asset_id" uuid NOT NULL,
        "sort_order" int NOT NULL DEFAULT 0,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_order_media" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_order_media_media_asset" UNIQUE ("media_asset_id"),
        CONSTRAINT "FK_order_media_order" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_order_media_asset" FOREIGN KEY ("media_asset_id") REFERENCES "media_assets"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(`CREATE INDEX "IDX_order_media_order_id" ON "order_media" ("order_id")`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "order_media"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "media_assets"`);
  }
}
