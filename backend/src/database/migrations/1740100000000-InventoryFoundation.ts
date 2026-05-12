import { MigrationInterface, QueryRunner } from 'typeorm';

export class InventoryFoundation1740100000000 implements MigrationInterface {
  name = 'InventoryFoundation1740100000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "inventory_items" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "organization_id" uuid NOT NULL,
        "item_type" character varying(24) NOT NULL DEFAULT 'material',
        "category" character varying(128),
        "name" character varying(512) NOT NULL,
        "description" text,
        "brand" character varying(256),
        "article" character varying(128),
        "sku" character varying(128),
        "barcode" character varying(128),
        "unit" character varying(32) NOT NULL DEFAULT 'pcs',
        "purchase_price_kopecks" integer,
        "sale_price_kopecks" integer,
        "min_stock" double precision NOT NULL DEFAULT 0,
        "track_stock" boolean NOT NULL DEFAULT true,
        "allow_fractional" boolean NOT NULL DEFAULT false,
        "is_active" boolean NOT NULL DEFAULT true,
        "external_id" character varying(128),
        "external_system" character varying(64),
        "sync_status" character varying(32),
        "last_synced_at" TIMESTAMPTZ,
        "created_by_user_id" uuid,
        "updated_by_user_id" uuid,
        "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
        CONSTRAINT "PK_inventory_items" PRIMARY KEY ("id"),
        CONSTRAINT "FK_inventory_items_organization" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_inventory_items_org" ON "inventory_items" ("organization_id")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_inventory_items_org_active" ON "inventory_items" ("organization_id", "is_active")`,
    );

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "stock_balances" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "organization_id" uuid NOT NULL,
        "inventory_item_id" uuid NOT NULL,
        "quantity_total" double precision NOT NULL DEFAULT 0,
        "quantity_reserved" double precision NOT NULL DEFAULT 0,
        "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
        CONSTRAINT "PK_stock_balances" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_stock_balances_item" UNIQUE ("inventory_item_id"),
        CONSTRAINT "FK_stock_balances_organization" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_stock_balances_item" FOREIGN KEY ("inventory_item_id") REFERENCES "inventory_items"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_stock_balances_org" ON "stock_balances" ("organization_id")`,
    );

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "inventory_movements" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "organization_id" uuid NOT NULL,
        "inventory_item_id" uuid NOT NULL,
        "stock_balance_id" uuid,
        "movement_type" character varying(32) NOT NULL,
        "source_type" character varying(32) NOT NULL DEFAULT 'manual',
        "quantity" double precision NOT NULL,
        "unit" character varying(32) NOT NULL DEFAULT 'pcs',
        "quantity_before_total" double precision NOT NULL,
        "quantity_after_total" double precision NOT NULL,
        "quantity_before_reserved" double precision NOT NULL,
        "quantity_after_reserved" double precision NOT NULL,
        "quantity_before_available" double precision NOT NULL,
        "quantity_after_available" double precision NOT NULL,
        "order_id" uuid,
        "order_work_item_id" uuid,
        "order_material_item_id" uuid,
        "purchase_order_id" uuid,
        "actor_user_id" uuid,
        "actor_employee_id" uuid,
        "actor_role" character varying(24),
        "actor_name_snapshot" character varying(255),
        "is_automatic" boolean NOT NULL DEFAULT false,
        "automatic_reason" text,
        "reason" text,
        "comment" text,
        "metadata" jsonb,
        "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
        CONSTRAINT "PK_inventory_movements" PRIMARY KEY ("id"),
        CONSTRAINT "FK_inventory_movements_organization" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_inventory_movements_item" FOREIGN KEY ("inventory_item_id") REFERENCES "inventory_items"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_inventory_movements_balance" FOREIGN KEY ("stock_balance_id") REFERENCES "stock_balances"("id") ON DELETE SET NULL
      )
    `);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_inventory_movements_org_created" ON "inventory_movements" ("organization_id", "created_at" DESC)`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_inventory_movements_item_created" ON "inventory_movements" ("inventory_item_id", "created_at" DESC)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "inventory_movements"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "stock_balances"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "inventory_items"`);
  }
}
