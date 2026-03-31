"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthSecurityFoundation1732900000000 = void 0;
class AuthSecurityFoundation1732900000000 {
    constructor() {
        this.name = 'AuthSecurityFoundation1732900000000';
    }
    async up(queryRunner) {
        await queryRunner.query(`
      ALTER TABLE "users"
      ADD COLUMN IF NOT EXISTS "email" varchar(320) NULL,
      ADD COLUMN IF NOT EXISTS "email_verified_at" TIMESTAMPTZ NULL
    `);
        await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "auth_otp_challenges" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "phone_digits" varchar(16) NOT NULL,
        "channel" varchar(24) NOT NULL DEFAULT 'sms',
        "code_hash" varchar(128) NOT NULL,
        "expires_at" TIMESTAMPTZ NOT NULL,
        "consumed_at" TIMESTAMPTZ NULL,
        "verify_fail_count" int NOT NULL DEFAULT 0,
        "send_count" int NOT NULL DEFAULT 1,
        "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
        "created_ip" varchar(64) NULL,
        CONSTRAINT "PK_auth_otp_challenges" PRIMARY KEY ("id")
      )
    `);
        await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_auth_otp_phone_created" ON "auth_otp_challenges" ("phone_digits", "created_at")`);
        await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "user_sessions" (
        "id" uuid NOT NULL,
        "family_id" uuid NOT NULL,
        "user_id" uuid NOT NULL,
        "refresh_hash" varchar(128) NOT NULL,
        "device_id" varchar(128) NULL,
        "device_name" varchar(256) NULL,
        "platform" varchar(32) NULL,
        "user_agent" varchar(512) NULL,
        "ip" varchar(64) NULL,
        "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
        "last_seen_at" TIMESTAMPTZ NULL,
        "revoked_at" TIMESTAMPTZ NULL,
        "replaced_by_session_id" uuid NULL,
        "jwt_audience" varchar(16) NOT NULL DEFAULT 'client',
        CONSTRAINT "PK_user_sessions" PRIMARY KEY ("id")
      )
    `);
        await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_user_sessions_user_revoked" ON "user_sessions" ("user_id", "revoked_at")`);
        await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_user_sessions_family" ON "user_sessions" ("family_id")`);
        await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "security_events" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "user_id" uuid NOT NULL,
        "type" varchar(64) NOT NULL,
        "metadata" jsonb NULL,
        "session_id" uuid NULL,
        "ip" varchar(64) NULL,
        "user_agent" varchar(512) NULL,
        "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
        CONSTRAINT "PK_security_events" PRIMARY KEY ("id")
      )
    `);
        await queryRunner.query(`CREATE INDEX IF NOT EXISTS "IDX_security_events_user_created" ON "security_events" ("user_id", "created_at")`);
    }
    async down(queryRunner) {
        await queryRunner.query(`DROP TABLE IF EXISTS "security_events"`);
        await queryRunner.query(`DROP TABLE IF EXISTS "user_sessions"`);
        await queryRunner.query(`DROP TABLE IF EXISTS "auth_otp_challenges"`);
        await queryRunner.query(`ALTER TABLE "users" DROP COLUMN IF EXISTS "email_verified_at"`);
        await queryRunner.query(`ALTER TABLE "users" DROP COLUMN IF EXISTS "email"`);
    }
}
exports.AuthSecurityFoundation1732900000000 = AuthSecurityFoundation1732900000000;
//# sourceMappingURL=1732900000000-AuthSecurityFoundation.js.map