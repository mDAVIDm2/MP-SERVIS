import { MigrationInterface, QueryRunner } from 'typeorm';

export class ServiceCatalogSuggestionReview1731650000000 implements MigrationInterface {
  name = 'ServiceCatalogSuggestionReview1731650000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "service_catalog_suggestions"
      ADD COLUMN IF NOT EXISTS "reviewed_at" TIMESTAMP NULL
    `);
    await queryRunner.query(`
      ALTER TABLE "service_catalog_suggestions"
      ADD COLUMN IF NOT EXISTS "review_note" text NULL
    `);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_scs_status_created" ON "service_catalog_suggestions" ("status", "created_at" DESC)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_scs_status_created"`);
    await queryRunner.query(`ALTER TABLE "service_catalog_suggestions" DROP COLUMN IF EXISTS "review_note"`);
    await queryRunner.query(`ALTER TABLE "service_catalog_suggestions" DROP COLUMN IF EXISTS "reviewed_at"`);
  }
}
