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
exports.NotificationsController = void 0;
const common_1 = require("@nestjs/common");
const passport_1 = require("@nestjs/passport");
const notifications_service_1 = require("./notifications.service");
function respectClientNotificationPrefs(req) {
    const h = req.headers?.['x-mp-servis-app'] ?? req.headers?.['X-MP-Servis-App'];
    const v = Array.isArray(h) ? h[0] : h;
    return String(v || '').toLowerCase() === 'client';
}
let NotificationsController = class NotificationsController {
    constructor(notifications) {
        this.notifications = notifications;
    }
    async registerDevice(req, body) {
        const raw = (body.fcm_app ?? '').toLowerCase();
        const fcmApp = raw === 'business' ? 'business' : 'client';
        await this.notifications.registerDevice(req.user.id, body.device_token, body.platform || 'android', fcmApp);
        return {};
    }
    async list(req, carId) {
        const respect = respectClientNotificationPrefs(req);
        return this.notifications.getNotifications(req.user.id, carId ?? undefined, respect);
    }
    async unreadCount(req) {
        const respect = respectClientNotificationPrefs(req);
        const count = await this.notifications.getUnreadCount(req.user.id, respect);
        return { count };
    }
    async unreadByCar(req) {
        const respect = respectClientNotificationPrefs(req);
        return this.notifications.getUnreadCountPerCar(req.user.id, respect);
    }
    async markAllRead(req, body) {
        await this.notifications.markAllAsRead(req.user.id, body.car_id);
        return { success: true };
    }
    async markReadByOrder(req, body) {
        const oid = body?.order_id?.trim();
        if (oid)
            await this.notifications.markUnreadAsReadByOrderId(req.user.id, oid);
        return { success: true };
    }
    async markReadByChat(req, body) {
        const cid = body?.chat_id?.trim();
        if (cid)
            await this.notifications.markUnreadAsReadByChatId(req.user.id, cid);
        return { success: true };
    }
    async markAsRead(req, id) {
        await this.notifications.markAsRead(req.user.id, id);
        return { success: true };
    }
    async delete(req, id) {
        await this.notifications.delete(req.user.id, id);
        return { success: true };
    }
};
exports.NotificationsController = NotificationsController;
__decorate([
    (0, common_1.Post)('register-device'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], NotificationsController.prototype, "registerDevice", null);
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Query)('car_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], NotificationsController.prototype, "list", null);
__decorate([
    (0, common_1.Get)('unread-count'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], NotificationsController.prototype, "unreadCount", null);
__decorate([
    (0, common_1.Get)('unread-by-car'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], NotificationsController.prototype, "unreadByCar", null);
__decorate([
    (0, common_1.Post)('mark-all-read'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], NotificationsController.prototype, "markAllRead", null);
__decorate([
    (0, common_1.Post)('mark-read-by-order'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], NotificationsController.prototype, "markReadByOrder", null);
__decorate([
    (0, common_1.Post)('mark-read-by-chat'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], NotificationsController.prototype, "markReadByChat", null);
__decorate([
    (0, common_1.Post)(':id/read'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], NotificationsController.prototype, "markAsRead", null);
__decorate([
    (0, common_1.Delete)(':id'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], NotificationsController.prototype, "delete", null);
exports.NotificationsController = NotificationsController = __decorate([
    (0, common_1.Controller)('notifications'),
    (0, common_1.UseGuards)((0, passport_1.AuthGuard)('jwt')),
    __metadata("design:paramtypes", [notifications_service_1.NotificationsService])
], NotificationsController);
//# sourceMappingURL=notifications.controller.js.map