import { MigrationInterface, QueryRunner } from 'typeorm';
import {
  SERVICE_CATALOG_CATEGORY_SORT_ORDER,
  catalogAllowedKindsForCategoryKey,
} from '../../reference/service-catalog-metadata';

/**
 * Позиция справочника: щётки стеклоочистителя (клиент ТО / запись).
 * Сиды на непустой БД не применяются — добавляем через миграцию.
 */
export class AddServiceCatalogWiperBlades1734800000000 implements MigrationInterface {
  name = 'AddServiceCatalogWiperBlades1734800000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    const categoryKey = 'maintenance';
    const cso = SERVICE_CATALOG_CATEGORY_SORT_ORDER[categoryKey] ?? 1000;
    const kinds = JSON.stringify(catalogAllowedKindsForCategoryKey(categoryKey));
    await queryRunner.query(
      `INSERT INTO "service_catalog_items" (
        "id", "category_key", "category_name", "category_sort_order", "name",
        "default_duration_minutes", "sort_order", "required_skill", "allowed_business_kinds"
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::jsonb)
      ON CONFLICT ("id") DO NOTHING`,
      [
        'svc_maint_wiper_blades',
        categoryKey,
        'ТО и обслуживание',
        cso,
        'Замена щёток стеклоочистителя',
        20,
        145,
        null,
        kinds,
      ],
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DELETE FROM "service_catalog_items" WHERE "id" = $1`, ['svc_maint_wiper_blades']);
  }
}
