import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Email-first OTP: challenges keyed by recipient + kind.
 * Телефон у пользователя может быть NULL; подтверждение телефона — отдельное поле phone_verified_at.
 */
export class EmailOtpRecipientAndNullablePhone1733000000000 implements MigrationInterface {
  name = 'EmailOtpRecipientAndNullablePhone1733000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "phone_verified_at" TIMESTAMPTZ NULL
    `);
    await queryRunner.query(`
      UPDATE "users" SET "phone_verified_at" = NOW()
      WHERE "phone" IS NOT NULL AND TRIM("phone") <> '' AND "phone_verified_at" IS NULL
    `);

    await queryRunner.query(`
      DO $$
      DECLARE r RECORD;
      BEGIN
        FOR r IN
          SELECT c.conname
          FROM pg_constraint c
          JOIN pg_class t ON c.conrelid = t.oid
          JOIN pg_namespace n ON t.relnamespace = n.oid
          WHERE n.nspname = 'public' AND t.relname = 'users' AND c.contype = 'u'
            AND pg_get_constraintdef(c.oid) LIKE '%phone%'
        LOOP
          EXECUTE format('ALTER TABLE users DROP CONSTRAINT IF EXISTS %I', r.conname);
        END LOOP;
      END $$;
    `);

    await queryRunner.query(`ALTER TABLE "users" ALTER COLUMN "phone" DROP NOT NULL`);

    await queryRunner.query(
      `CREATE UNIQUE INDEX IF NOT EXISTS "UQ_users_phone_nonnull" ON "users" ("phone") WHERE "phone" IS NOT NULL AND TRIM("phone") <> ''`,
    );
    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS "UQ_users_email_lower_nonnull"
      ON "users" (LOWER(TRIM("email")))
      WHERE "email" IS NOT NULL AND TRIM("email") <> ''
    `);

    await queryRunner.query(`
      ALTER TABLE "auth_otp_challenges" ADD COLUMN IF NOT EXISTS "recipient" varchar(320) NOT NULL DEFAULT ''
    `);
    await queryRunner.query(`
      ALTER TABLE "auth_otp_challenges" ADD COLUMN IF NOT EXISTS "recipient_kind" varchar(16) NOT NULL DEFAULT 'phone'
    `);
    await queryRunner.query(`
      ALTER TABLE "auth_otp_challenges" ADD COLUMN IF NOT EXISTS "status" varchar(24) NOT NULL DEFAULT 'pending'
    `);

    await queryRunner.query(`
      UPDATE "auth_otp_challenges"
      SET "recipient" = "phone_digits", "recipient_kind" = 'phone'
      WHERE "recipient" = '' OR "recipient" IS NULL
    `);

    await queryRunner.query(`
      UPDATE "auth_otp_challenges" SET "status" = CASE
        WHEN "consumed_at" IS NOT NULL THEN 'consumed'
        WHEN "verify_fail_count" >= 5 THEN 'locked'
        ELSE 'pending'
      END
    `);

    await queryRunner.query(`
      ALTER TABLE "auth_otp_challenges" RENAME COLUMN "verify_fail_count" TO "attempts_count"
    `);

    await queryRunner.query(`ALTER TABLE "auth_otp_challenges" DROP COLUMN IF EXISTS "phone_digits"`);

    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_otp_recipient_created" ON "auth_otp_challenges" ("recipient", "recipient_kind", "created_at")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_otp_recipient_created"`);
    await queryRunner.query(`
      ALTER TABLE "auth_otp_challenges" ADD COLUMN IF NOT EXISTS "phone_digits" varchar(16) NOT NULL DEFAULT ''
    `);
    await queryRunner.query(`
      UPDATE "auth_otp_challenges" SET "phone_digits" = "recipient" WHERE "recipient_kind" = 'phone'
    `);
    await queryRunner.query(`
      ALTER TABLE "auth_otp_challenges" RENAME COLUMN "attempts_count" TO "verify_fail_count"
    `);
    await queryRunner.query(`ALTER TABLE "auth_otp_challenges" DROP COLUMN IF EXISTS "status"`);
    await queryRunner.query(`ALTER TABLE "auth_otp_challenges" DROP COLUMN IF EXISTS "recipient_kind"`);
    await queryRunner.query(`ALTER TABLE "auth_otp_challenges" DROP COLUMN IF EXISTS "recipient"`);

    await queryRunner.query(`DROP INDEX IF EXISTS "UQ_users_email_lower_nonnull"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "UQ_users_phone_nonnull"`);

    await queryRunner.query(`
      UPDATE "users" SET "phone" = '' WHERE "phone" IS NULL
    `);
    await queryRunner.query(`ALTER TABLE "users" ALTER COLUMN "phone" SET NOT NULL`);
    await queryRunner.query(`
      ALTER TABLE "users" ADD CONSTRAINT "UQ_users_phone_legacy" UNIQUE ("phone")
    `);

    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN IF EXISTS "phone_verified_at"`);
  }
}
