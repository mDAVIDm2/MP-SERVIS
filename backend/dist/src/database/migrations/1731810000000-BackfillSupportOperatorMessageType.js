"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.BackfillSupportOperatorMessageType1731810000000 = void 0;
class BackfillSupportOperatorMessageType1731810000000 {
    constructor() {
        this.name = 'BackfillSupportOperatorMessageType1731810000000';
    }
    async up(queryRunner) {
        await queryRunner.query(`
      UPDATE "chat_messages"
      SET "message_type" = 'support_operator_reply'
      WHERE "is_from_support_operator" = true
        AND ("message_type" IS NULL OR "message_type" = '')
    `);
    }
    async down(queryRunner) {
        await queryRunner.query(`
      UPDATE "chat_messages"
      SET "message_type" = NULL
      WHERE "message_type" = 'support_operator_reply'
        AND "is_from_support_operator" = true
    `);
    }
}
exports.BackfillSupportOperatorMessageType1731810000000 = BackfillSupportOperatorMessageType1731810000000;
//# sourceMappingURL=1731810000000-BackfillSupportOperatorMessageType.js.map