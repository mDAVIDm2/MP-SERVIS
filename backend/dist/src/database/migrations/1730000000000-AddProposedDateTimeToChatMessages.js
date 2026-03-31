"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AddProposedDateTimeToChatMessages1730000000000 = void 0;
class AddProposedDateTimeToChatMessages1730000000000 {
    constructor() {
        this.name = 'AddProposedDateTimeToChatMessages1730000000000';
    }
    async up(queryRunner) {
        await queryRunner.query(`
      ALTER TABLE "chat_messages"
      ADD COLUMN IF NOT EXISTS "proposed_date_time" TIMESTAMP WITH TIME ZONE NULL
    `);
    }
    async down(queryRunner) {
        await queryRunner.query(`
      ALTER TABLE "chat_messages"
      DROP COLUMN IF EXISTS "proposed_date_time"
    `);
    }
}
exports.AddProposedDateTimeToChatMessages1730000000000 = AddProposedDateTimeToChatMessages1730000000000;
//# sourceMappingURL=1730000000000-AddProposedDateTimeToChatMessages.js.map