"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.UserNotificationPreferences1731900000000 = void 0;
const typeorm_1 = require("typeorm");
class UserNotificationPreferences1731900000000 {
    constructor() {
        this.name = 'UserNotificationPreferences1731900000000';
    }
    async up(queryRunner) {
        await queryRunner.addColumn('users', new typeorm_1.TableColumn({
            name: 'notification_preferences',
            type: 'jsonb',
            isNullable: true,
        }));
    }
    async down(queryRunner) {
        await queryRunner.dropColumn('users', 'notification_preferences');
    }
}
exports.UserNotificationPreferences1731900000000 = UserNotificationPreferences1731900000000;
//# sourceMappingURL=1731900000000-UserNotificationPreferences.js.map