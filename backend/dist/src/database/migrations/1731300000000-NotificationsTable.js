"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.NotificationsTable1731300000000 = void 0;
class NotificationsTable1731300000000 {
    constructor() {
        this.name = 'NotificationsTable1731300000000';
    }
    async up(queryRunner) {
        await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "notifications" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "user_id" varchar(64) NOT NULL,
        "car_id" varchar(64) NULL,
        "type" varchar(64) NOT NULL,
        "title" varchar(256) NOT NULL,
        "body" text NULL,
        "is_read" boolean NOT NULL DEFAULT false,
        "payload" jsonb NULL,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_notifications" PRIMARY KEY ("id")
      )
    `);
        await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_notifications_user_id" ON "notifications" ("user_id")`);
        await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_notifications_car_id" ON "notifications" ("car_id")`);
        await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_notifications_is_read" ON "notifications" ("is_read")`);
    }
    async down(queryRunner) {
        await queryRunner.query(`DROP TABLE IF EXISTS "notifications"`);
    }
}
exports.NotificationsTable1731300000000 = NotificationsTable1731300000000;
//# sourceMappingURL=1731300000000-NotificationsTable.js.map