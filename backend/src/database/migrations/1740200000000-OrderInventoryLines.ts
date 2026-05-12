import { MigrationInterface, QueryRunner } from 'typeorm';

export class OrderInventoryLines1740200000000 implements MigrationInterface {
  name = 'OrderInventoryLines1740200000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "order_inventory_lines" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "organization_id" uuid NOT NULL,
        "order_id" uuid NOT NULL,
        "inventory_item_id" uuid NOT NULL,
        "order_item_id" uuid,
        "quantity_planned" double precision NOT NULL,
        "quantity_reserved" double precision NOT NULL DEFAULT 0,
        "unit" character varying(32) NOT NULL DEFAULT 'pcs',
        "status" character varying(32) NOT NULL DEFAULT 'planned',
        "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
        CONSTRAINT "PK_order_inventory_lines" PRIMARY KEY ("id"),
        CONSTRAINT "FK_order_inventory_lines_organization" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_order_inventory_lines_order" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_order_inventory_lines_inventory_item" FOREIGN KEY ("inventory_item_id") REFERENCES "inventory_items"("id") ON DELETE RESTRICT,
        CONSTRAINT "FK_order_inventory_lines_order_item" FOREIGN KEY ("order_item_id") REFERENCES "order_items"("id") ON DELETE SET NULL
      )
    `);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_order_inventory_lines_order" ON "order_inventory_lines" ("order_id")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_order_inventory_lines_order_status" ON "order_inventory_lines" ("order_id", "status")`,
    );
    await queryRunner.query(
      `ALTER TABLE "inventory_movements" ADD COLUMN IF NOT EXISTS "order_inventory_line_id" uuid`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "inventory_movements" DROP COLUMN IF EXISTS "order_inventory_line_id"`,
    );
    await queryRunner.query(`DROP TABLE IF EXISTS "order_inventory_lines"`);
  }
}
