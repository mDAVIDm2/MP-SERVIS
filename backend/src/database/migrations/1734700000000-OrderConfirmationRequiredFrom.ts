import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Кто обязан подтвердить запись в статусе pending_confirmation:
 * organization — инициатор заказа клиент (нужен ответ СТО);
 * client — заказ создала организация (нужен ответ клиента).
 */
export class OrderConfirmationRequiredFrom1734700000000 implements MigrationInterface {
  name = 'OrderConfirmationRequiredFrom1734700000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "orders"
      ADD COLUMN IF NOT EXISTS "confirmation_required_from" varchar(20) NOT NULL DEFAULT 'organization'
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "orders" DROP COLUMN IF EXISTS "confirmation_required_from"`);
  }
}
