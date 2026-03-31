"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.FixInternalOperatorsEmailNotNull1731100000000 = void 0;
class FixInternalOperatorsEmailNotNull1731100000000 {
    constructor() {
        this.name = 'FixInternalOperatorsEmailNotNull1731100000000';
    }
    async up(queryRunner) {
        await queryRunner.query(`DELETE FROM internal_operators WHERE email IS NULL`);
        await queryRunner.query(`ALTER TABLE internal_operators ALTER COLUMN email SET NOT NULL`);
    }
    async down(queryRunner) {
        await queryRunner.query(`ALTER TABLE internal_operators ALTER COLUMN email DROP NOT NULL`);
    }
}
exports.FixInternalOperatorsEmailNotNull1731100000000 = FixInternalOperatorsEmailNotNull1731100000000;
//# sourceMappingURL=1731100000000-FixInternalOperatorsEmailNotNull.js.map