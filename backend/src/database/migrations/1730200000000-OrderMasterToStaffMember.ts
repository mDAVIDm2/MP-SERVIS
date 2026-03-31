import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Меняем FK orders.master_id: было users.id, стало staff_members.id,
 * чтобы назначение мастера из списка персонала СТО работало.
 */
export class OrderMasterToStaffMember1730200000000 implements MigrationInterface {
  name = 'OrderMasterToStaffMember1730200000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "orders" DROP CONSTRAINT IF EXISTS "FK_6373fc0c675837fe8dafab8c075"`,
    );
    // Обнуляем master_id: старые значения ссылались на users, новые — на staff_members
    await queryRunner.query(
      `UPDATE "orders" SET "master_id" = NULL WHERE "master_id" IS NOT NULL AND "master_id" NOT IN (SELECT "id" FROM "staff_members")`,
    );
    await queryRunner.query(
      `ALTER TABLE "orders" ADD CONSTRAINT "FK_orders_master_staff" ` +
        `FOREIGN KEY ("master_id") REFERENCES "staff_members"("id") ON DELETE SET NULL`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "orders" DROP CONSTRAINT IF EXISTS "FK_orders_master_staff"`,
    );
    await queryRunner.query(
      `ALTER TABLE "orders" ADD CONSTRAINT "FK_6373fc0c675837fe8dafab8c075" ` +
        `FOREIGN KEY ("master_id") REFERENCES "users"("id") ON DELETE SET NULL`,
    );
  }
}
