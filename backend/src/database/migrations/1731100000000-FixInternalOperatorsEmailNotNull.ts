import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Удаляет строки с NULL в email и выставляет NOT NULL для колонки email.
 */
export class FixInternalOperatorsEmailNotNull1731100000000 implements MigrationInterface {
  name = 'FixInternalOperatorsEmailNotNull1731100000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DELETE FROM internal_operators WHERE email IS NULL`,
    );
    await queryRunner.query(
      `ALTER TABLE internal_operators ALTER COLUMN email SET NOT NULL`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE internal_operators ALTER COLUMN email DROP NOT NULL`,
    );
  }
}
