"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PushDeviceFcmApp1732100000000 = void 0;
class PushDeviceFcmApp1732100000000 {
    constructor() {
        this.name = 'PushDeviceFcmApp1732100000000';
    }
    async up(queryRunner) {
        await queryRunner.query(`
      ALTER TABLE "push_devices"
      ADD COLUMN IF NOT EXISTS "fcm_app" varchar(16) NOT NULL DEFAULT 'client'
    `);
    }
    async down(queryRunner) {
        await queryRunner.query(`ALTER TABLE "push_devices" DROP COLUMN IF EXISTS "fcm_app"`);
    }
}
exports.PushDeviceFcmApp1732100000000 = PushDeviceFcmApp1732100000000;
//# sourceMappingURL=1732100000000-PushDeviceFcmApp.js.map