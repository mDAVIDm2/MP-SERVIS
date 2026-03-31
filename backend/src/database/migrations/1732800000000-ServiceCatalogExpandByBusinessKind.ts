import { MigrationInterface, QueryRunner } from 'typeorm';
import { SERVICE_CATALOG_SEED_EXTRA } from '../../reference/service-catalog.seed-extra';
import {
  SERVICE_CATALOG_CATEGORY_SORT_ORDER,
  catalogAllowedKindsForCategoryKey,
} from '../../reference/service-catalog-metadata';

/**
 * Расширение справочника: мойки, детейлинг, автозвук, стёкла, доп. позиции СТО.
 * Обновляет allowed_business_kinds для категорий body и diagnostics (мойка / детейлинг).
 */
export class ServiceCatalogExpandByBusinessKind1732800000000 implements MigrationInterface {
  name = 'ServiceCatalogExpandByBusinessKind1732800000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    for (const row of SERVICE_CATALOG_SEED_EXTRA) {
      const cso = SERVICE_CATALOG_CATEGORY_SORT_ORDER[row.categoryKey] ?? 1000;
      const kinds = JSON.stringify(catalogAllowedKindsForCategoryKey(row.categoryKey));
      await queryRunner.query(
        `INSERT INTO "service_catalog_items" (
          "id", "category_key", "category_name", "category_sort_order", "name",
          "default_duration_minutes", "sort_order", "required_skill", "allowed_business_kinds"
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::jsonb)
        ON CONFLICT ("id") DO NOTHING`,
        [
          row.id,
          row.categoryKey,
          row.categoryName,
          cso,
          row.name,
          row.defaultDurationMinutes,
          row.sortOrder,
          row.requiredSkill ?? null,
          kinds,
        ],
      );
    }

    await queryRunner.query(`
      UPDATE "service_catalog_items"
      SET "allowed_business_kinds" = '["sto","body_shop","detailing","glass","car_wash","other"]'::jsonb
      WHERE "category_key" = 'body'
    `);
    await queryRunner.query(`
      UPDATE "service_catalog_items"
      SET "allowed_business_kinds" = '["sto","tire_service","ev_service","detailing","other"]'::jsonb
      WHERE "category_key" = 'diagnostics'
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    for (const row of SERVICE_CATALOG_SEED_EXTRA) {
      await queryRunner.query(`DELETE FROM "service_catalog_items" WHERE "id" = $1`, [row.id]);
    }

    await queryRunner.query(`
      UPDATE "service_catalog_items"
      SET "allowed_business_kinds" = '["sto","body_shop","detailing","glass","other"]'::jsonb
      WHERE "category_key" = 'body'
    `);
    await queryRunner.query(`
      UPDATE "service_catalog_items"
      SET "allowed_business_kinds" = '["sto","tire_service","ev_service","other"]'::jsonb
      WHERE "category_key" = 'diagnostics'
    `);
  }
}
