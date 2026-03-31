"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SmartScheduling1730300000000 = void 0;
class SmartScheduling1730300000000 {
    constructor() {
        this.name = 'SmartScheduling1730300000000';
    }
    async up(queryRunner) {
        await queryRunner.query(`CREATE EXTENSION IF NOT EXISTS "uuid-ossp"`);
        await queryRunner.query(`ALTER TABLE "staff_members" ADD COLUMN IF NOT EXISTS "skills" jsonb NOT NULL DEFAULT '[]'::jsonb`);
        await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "master_schedules" (
        "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        "master_id" uuid NOT NULL REFERENCES "staff_members"("id") ON DELETE CASCADE,
        "day_of_week" smallint NOT NULL,
        "start_time" varchar(5) NOT NULL DEFAULT '09:00',
        "end_time" varchar(5) NOT NULL DEFAULT '18:00',
        "is_working_day" boolean NOT NULL DEFAULT true
      )
    `);
        await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_master_schedules_master_id" ON "master_schedules" ("master_id")`);
        await queryRunner.query(`ALTER TABLE "orders" ADD COLUMN IF NOT EXISTS "planned_start_time" timestamptz`);
        await queryRunner.query(`ALTER TABLE "orders" ADD COLUMN IF NOT EXISTS "planned_end_time" timestamptz`);
        await queryRunner.query(`ALTER TABLE "orders" ADD COLUMN IF NOT EXISTS "actual_start_time" timestamptz`);
        await queryRunner.query(`ALTER TABLE "orders" ADD COLUMN IF NOT EXISTS "actual_end_time" timestamptz`);
        await queryRunner.query(`UPDATE "orders" SET planned_start_time = date_time, planned_end_time = date_time + interval '1 hour' WHERE planned_start_time IS NULL`);
        await queryRunner.query(`ALTER TABLE "order_items" ADD COLUMN IF NOT EXISTS "master_id" uuid REFERENCES "staff_members"("id") ON DELETE SET NULL`);
    }
    async down(queryRunner) {
        await queryRunner.query(`ALTER TABLE "order_items" DROP COLUMN IF EXISTS "master_id"`);
        await queryRunner.query(`ALTER TABLE "orders" DROP COLUMN IF EXISTS "actual_end_time"`);
        await queryRunner.query(`ALTER TABLE "orders" DROP COLUMN IF EXISTS "actual_start_time"`);
        await queryRunner.query(`ALTER TABLE "orders" DROP COLUMN IF EXISTS "planned_end_time"`);
        await queryRunner.query(`ALTER TABLE "orders" DROP COLUMN IF EXISTS "planned_start_time"`);
        await queryRunner.query(`DROP TABLE IF EXISTS "master_schedules"`);
        await queryRunner.query(`ALTER TABLE "staff_members" DROP COLUMN IF EXISTS "skills"`);
    }
}
exports.SmartScheduling1730300000000 = SmartScheduling1730300000000;
//# sourceMappingURL=1730300000000-SmartScheduling.js.map