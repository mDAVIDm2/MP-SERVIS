import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Раздельные аккаунты «клиент» и «бизнес» для одного email/телефона:
 * уникальность контакта в паре с account_realm.
 */
export class UserAccountRealm1733200000000 implements MigrationInterface {
  name = 'UserAccountRealm1733200000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "users"
      ADD COLUMN IF NOT EXISTS "account_realm" varchar(16) NOT NULL DEFAULT 'business'
    `);
    await queryRunner.query(`
      UPDATE "users" SET "account_realm" = 'business' WHERE "account_realm" IS NULL OR "account_realm" = ''
    `);

    // Старые дубликаты по телефону/email (один номер на несколько строк) ломают уникальность (phone, realm).
    // Оставляем по одному business; вторая строка — client; остальным обнуляем контакт.
    await queryRunner.query(`
      UPDATE "users" u
      SET "account_realm" = 'client'
      FROM (
        SELECT "id", ROW_NUMBER() OVER (PARTITION BY "phone" ORDER BY "id") AS rn
        FROM "users"
        WHERE "phone" IS NOT NULL AND TRIM("phone") <> ''
      ) r
      WHERE u."id" = r."id" AND r.rn = 2
    `);
    await queryRunner.query(`
      UPDATE "users" u
      SET "phone" = NULL
      FROM (
        SELECT "id", ROW_NUMBER() OVER (PARTITION BY "phone" ORDER BY "id") AS rn
        FROM "users"
        WHERE "phone" IS NOT NULL AND TRIM("phone") <> ''
      ) r
      WHERE u."id" = r."id" AND r.rn > 2
    `);
    await queryRunner.query(`
      UPDATE "users" u
      SET "account_realm" = 'client'
      FROM (
        SELECT "id", ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM("email")) ORDER BY "id") AS rn
        FROM "users"
        WHERE "email" IS NOT NULL AND TRIM("email") <> ''
      ) r
      WHERE u."id" = r."id" AND r.rn = 2
    `);
    await queryRunner.query(`
      UPDATE "users" u
      SET "email" = NULL
      FROM (
        SELECT "id", ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM("email")) ORDER BY "id") AS rn
        FROM "users"
        WHERE "email" IS NOT NULL AND TRIM("email") <> ''
      ) r
      WHERE u."id" = r."id" AND r.rn > 2
    `);

    await queryRunner.query(`DROP INDEX IF EXISTS "UQ_users_email_lower_nonnull"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "UQ_users_phone_nonnull"`);

    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS "UQ_users_email_realm"
      ON "users" (LOWER(TRIM("email")), "account_realm")
      WHERE "email" IS NOT NULL AND TRIM("email") <> ''
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS "UQ_users_phone_realm"
      ON "users" ("phone", "account_realm")
      WHERE "phone" IS NOT NULL AND TRIM("phone") <> ''
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "UQ_users_phone_realm"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "UQ_users_email_realm"`);

    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS "UQ_users_email_lower_nonnull"
      ON "users" (LOWER(TRIM("email")))
      WHERE "email" IS NOT NULL AND TRIM("email") <> ''
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS "UQ_users_phone_nonnull"
      ON "users" ("phone")
      WHERE "phone" IS NOT NULL AND TRIM("phone") <> ''
    `);

    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN IF EXISTS "account_realm"`);
  }
}
