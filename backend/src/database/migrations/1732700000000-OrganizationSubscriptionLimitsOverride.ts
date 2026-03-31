import { MigrationInterface, QueryRunner } from 'typeorm';

export class OrganizationSubscriptionLimitsOverride1732700000000 implements MigrationInterface {
  name = 'OrganizationSubscriptionLimitsOverride1732700000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "organization_subscriptions"
      ADD COLUMN IF NOT EXISTS "limits_override" jsonb NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "organization_subscriptions" DROP COLUMN IF EXISTS "limits_override"
    `);
  }
}
