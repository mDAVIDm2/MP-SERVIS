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
exports.ChatsController = void 0;
const common_1 = require("@nestjs/common");
const passport_1 = require("@nestjs/passport");
const platform_express_1 = require("@nestjs/platform-express");
const request_app_util_1 = require("../common/request-app.util");
const chats_service_1 = require("./chats.service");
let ChatsController = class ChatsController {
    constructor(chats) {
        this.chats = chats;
    }
    async openSupport(req) {
        const user = req.user;
        const phone = user?.phone != null ? String(user.phone).replace(/\D/g, '') : '';
        if (!phone)
            throw new common_1.BadRequestException('В профиле не указан телефон');
        const chat = await this.chats.getOrCreateSupportChat(phone);
        return this.chats.getChatById(chat.id, null, phone, true);
    }
    async list(req) {
        const user = req.user;
        const phone = user?.phone != null ? String(user.phone).replace(/\D/g, '') : '';
        if ((0, request_app_util_1.isClientAppRequest)(req)) {
            if (!phone)
                return { items: [] };
            try {
                return await this.chats.getChatsForClient(phone);
            }
            catch (err) {
                console.error('[Chats] getChatsForClient error:', err);
                return { items: [] };
            }
        }
        const orgId = user?.organizationId;
        if (orgId && phone) {
            try {
                return await this.chats.getChatsWithSupportForStaff(orgId, phone);
            }
            catch (err) {
                console.error('[Chats] getChatsWithSupportForStaff error:', err);
                return this.chats.getChats(orgId);
            }
        }
        if (orgId)
            return this.chats.getChats(orgId);
        if (!phone)
            return { items: [] };
        try {
            return await this.chats.getChatsForClient(phone);
        }
        catch (err) {
            console.error('[Chats] getChatsForClient error:', err);
            return { items: [] };
        }
    }
    async getMessages(id, req) {
        const user = req.user;
        const asClient = (0, request_app_util_1.isClientAppRequest)(req);
        const phone = user?.phone != null ? String(user.phone).replace(/\D/g, '') : '';
        const orgId = user?.organizationId ?? null;
        return this.chats.getMessagesForParticipant(id, orgId, phone || null, asClient);
    }
    async getAttachmentFile(chatId, assetId, req, res) {
        const user = req.user;
        const asClient = (0, request_app_util_1.isClientAppRequest)(req);
        const phone = user?.phone != null ? String(user.phone).replace(/\D/g, '') : '';
        const orgId = user?.organizationId ?? null;
        const filePath = await this.chats.resolveChatAttachmentLocalPath(chatId, assetId, orgId, phone || null, asClient);
        if (!filePath)
            return res.status(404).send('Not found');
        return res.sendFile(filePath);
    }
    async getOne(id, req) {
        const user = req.user;
        const orgId = user?.organizationId ?? null;
        const phone = user?.phone != null ? String(user.phone).replace(/\D/g, '') : '';
        const asClient = (0, request_app_util_1.isClientAppRequest)(req);
        return this.chats.getChatById(id, orgId, phone || null, asClient);
    }
    async markRead(id, req) {
        const user = req.user;
        const asClient = (0, request_app_util_1.isClientAppRequest)(req);
        const phone = user?.phone != null ? String(user.phone).replace(/\D/g, '') : '';
        const orgId = user?.organizationId ?? null;
        await this.chats.markChatRead(id, orgId, phone || null, asClient);
    }
    async sendMessageWithMedia(id, req, body, files) {
        const user = req.user;
        const chat = await this.chats.findChatForAccess(id);
        if (!chat)
            throw new common_1.NotFoundException('Chat not found');
        const phoneNorm = user?.phone != null ? String(user.phone).replace(/\D/g, '') : '';
        const orgId = user?.organizationId ?? null;
        const asClient = (0, request_app_util_1.isClientAppRequest)(req);
        this.chats.validateChatAccess(chat, orgId, phoneNorm || null, asClient);
        const cphone = chat.clientPhone != null ? String(chat.clientPhone).replace(/\D/g, '') : '';
        const isSupportChat = chat.organizationId == null && !!cphone;
        const isFromClient = (0, request_app_util_1.isClientAppRequest)(req) || !user?.organizationId || (isSupportChat && !!user?.organizationId);
        let supportChannel = null;
        if (isSupportChat && isFromClient) {
            supportChannel = (0, request_app_util_1.isClientAppRequest)(req) ? 'client' : 'business';
        }
        return this.chats.sendMessageWithMedia(id, body ?? {}, files, isFromClient, { userOrgId: orgId, userPhoneNorm: phoneNorm || null, asClient }, { supportChannel, uploadedByUserId: user?.id ?? null });
    }
    async sendMessage(id, req, body) {
        const user = req.user;
        const chat = await this.chats.findChatForAccess(id);
        if (!chat)
            throw new common_1.NotFoundException('Chat not found');
        const phoneNorm = user?.phone != null ? String(user.phone).replace(/\D/g, '') : '';
        const orgId = user?.organizationId ?? null;
        const asClient = (0, request_app_util_1.isClientAppRequest)(req);
        this.chats.validateChatAccess(chat, orgId, phoneNorm || null, asClient);
        const cphone = chat.clientPhone != null ? String(chat.clientPhone).replace(/\D/g, '') : '';
        const isSupportChat = chat.organizationId == null && !!cphone;
        const isFromClient = (0, request_app_util_1.isClientAppRequest)(req) || !user?.organizationId || (isSupportChat && !!user?.organizationId);
        let supportChannel = null;
        if (isSupportChat && isFromClient) {
            supportChannel = (0, request_app_util_1.isClientAppRequest)(req) ? 'client' : 'business';
        }
        return this.chats.sendMessage(id, body, isFromClient, { supportChannel });
    }
};
exports.ChatsController = ChatsController;
__decorate([
    (0, common_1.Post)('support/open'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], ChatsController.prototype, "openSupport", null);
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], ChatsController.prototype, "list", null);
__decorate([
    (0, common_1.Get)(':id/messages'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], ChatsController.prototype, "getMessages", null);
__decorate([
    (0, common_1.Get)(':id/attachments/:assetId/file'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Param)('assetId')),
    __param(2, (0, common_1.Req)()),
    __param(3, (0, common_1.Res)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, Object, Object]),
    __metadata("design:returntype", Promise)
], ChatsController.prototype, "getAttachmentFile", null);
__decorate([
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], ChatsController.prototype, "getOne", null);
__decorate([
    (0, common_1.Post)(':id/read'),
    (0, common_1.HttpCode)(204),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], ChatsController.prototype, "markRead", null);
__decorate([
    (0, common_1.Post)(':id/messages/with-media'),
    (0, common_1.UseInterceptors)((0, platform_express_1.FilesInterceptor)('files', 20)),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __param(2, (0, common_1.Body)()),
    __param(3, (0, common_1.UploadedFiles)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object, Object]),
    __metadata("design:returntype", Promise)
], ChatsController.prototype, "sendMessageWithMedia", null);
__decorate([
    (0, common_1.Post)(':id/messages'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], ChatsController.prototype, "sendMessage", null);
exports.ChatsController = ChatsController = __decorate([
    (0, common_1.Controller)('chats'),
    (0, common_1.UseGuards)((0, passport_1.AuthGuard)('jwt')),
    __metadata("design:paramtypes", [chats_service_1.ChatsService])
], ChatsController);
//# sourceMappingURL=chats.controller.js.map