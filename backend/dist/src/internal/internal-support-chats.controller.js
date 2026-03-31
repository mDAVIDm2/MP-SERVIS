"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.InternalSupportChatsController = void 0;
const common_1 = require("@nestjs/common");
const internal_jwt_guard_1 = require("./internal-jwt.guard");
const chats_service_1 = require("../chats/chats.service");
let InternalSupportChatsController = class InternalSupportChatsController {
    constructor(chats) {
        this.chats = chats;
    }
    async list() {
        return this.chats.listSupportChatsForInternal();
    }
    async messages(id) {
        return this.chats.getInternalSupportChatMessages(id);
    }
    async send(id, body) {
        return this.chats.postInternalSupportOperatorMessage(id, body?.text ?? '');
    }
    async markRead(id) {
        await this.chats.markInternalSupportChatRead(id);
    }
};
exports.InternalSupportChatsController = InternalSupportChatsController;
__decorate([
    (0, common_1.Get)(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], InternalSupportChatsController.prototype, "list", null);
__decorate([
    (0, common_1.Get)(':id/messages'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], InternalSupportChatsController.prototype, "messages", null);
__decorate([
    (0, common_1.Post)(':id/messages'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], InternalSupportChatsController.prototype, "send", null);
__decorate([
    (0, common_1.Post)(':id/read'),
    (0, common_1.HttpCode)(204),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], InternalSupportChatsController.prototype, "markRead", null);
exports.InternalSupportChatsController = InternalSupportChatsController = __decorate([
    (0, common_1.Controller)('internal/support-chats'),
    (0, common_1.UseGuards)(internal_jwt_guard_1.InternalJwtAuthGuard),
    __metadata("design:paramtypes", [chats_service_1.ChatsService])
], InternalSupportChatsController);
//# sourceMappingURL=internal-support-chats.controller.js.map