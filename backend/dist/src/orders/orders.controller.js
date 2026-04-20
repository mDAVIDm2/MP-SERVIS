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
exports.OrdersController = void 0;
const common_1 = require("@nestjs/common");
const passport_1 = require("@nestjs/passport");
const platform_express_1 = require("@nestjs/platform-express");
const common_2 = require("@nestjs/common");
const request_app_util_1 = require("../common/request-app.util");
const orders_service_1 = require("./orders.service");
let OrdersController = class OrdersController {
    constructor(orders) {
        this.orders = orders;
    }
    async list(req) {
        const user = req.user;
        const phone = user?.phone ? String(user.phone).replace(/\D/g, '') : '';
        if ((0, request_app_util_1.isClientAppRequest)(req)) {
            if (!phone)
                return { items: [] };
            return this.orders.findForClient(phone);
        }
        const orgId = user?.organizationId;
        if (orgId)
            return this.orders.findAll(orgId);
        if (!phone)
            return { items: [] };
        return this.orders.findForClient(phone);
    }
    async getPhotos(orderId) {
        const result = await this.orders.getOrderPhotos(orderId);
        if (!result)
            throw new Error('Not found');
        return result;
    }
    async addPhoto(orderId, file, req) {
        if (!file || !file.buffer)
            throw new Error('No file');
        const result = await this.orders.addOrderPhoto(orderId, file, {
            uploadedByUserId: req.user?.id ?? null,
        });
        if (!result)
            throw new Error('Not found');
        return result;
    }
    async getPhotoFile(orderId, photoId, res) {
        const filePath = await this.orders.getOrderPhotoFile(orderId, photoId);
        if (!filePath)
            return res.status(404).send('Not found');
        return res.sendFile(filePath);
    }
    async get(id, req) {
        const user = req.user;
        const clientMode = (0, request_app_util_1.isClientAppRequest)(req);
        const orgId = user?.organizationId;
        const clientLike = clientMode || (!orgId && user?.phone);
        const o = await this.orders.findOne(id, clientLike && user?.id ? user.id : undefined);
        if (!o)
            throw new common_1.NotFoundException('Order not found');
        const userPhone = user?.phone ? this.orders.normalizePhoneForCompare(user.phone) : '';
        if (clientMode || (!orgId && user?.phone)) {
            const orderPhone = this.orders.normalizePhoneForCompare(o.client_phone);
            if (!userPhone || orderPhone !== userPhone)
                throw new common_1.NotFoundException('Order not found');
        }
        else if (orgId) {
            if (o.organization_id !== orgId)
                throw new common_1.NotFoundException('Order not found');
        }
        else {
            throw new common_1.NotFoundException('Order not found');
        }
        return o;
    }
    async create(req, body) {
        const user = req.user;
        const clientMode = (0, request_app_util_1.isClientAppRequest)(req);
        if (clientMode) {
            if (body?.organization_id && user?.phone) {
                const phone = String(user.phone).replace(/\D/g, '');
                const dto = {
                    ...body,
                    client_phone: phone,
                    client_name: body.client_name ?? user.name ?? 'Клиент',
                };
                return this.orders.create(body.organization_id, dto);
            }
            throw new common_1.BadRequestException('Укажите organization_id');
        }
        const orgId = user?.organizationId;
        if (orgId)
            return this.orders.create(orgId, body);
        if (body?.organization_id && user?.phone) {
            const phone = String(user.phone).replace(/\D/g, '');
            const dto = {
                ...body,
                client_phone: phone,
                client_name: body.client_name ?? user.name ?? 'Клиент',
            };
            return this.orders.create(body.organization_id, dto);
        }
        throw new common_1.BadRequestException('Нет активной организации');
    }
    async clearAll(req) {
        const orgId = req.user?.organizationId;
        if (!orgId)
            throw new common_1.BadRequestException('Доступно только для организации');
        return this.orders.clearAllOrders(orgId);
    }
    async updateStatus(id, status) {
        return this.orders.updateStatus(id, status);
    }
    async updateTime(id, body) {
        const result = await this.orders.updateTime(id, body);
        if (!result)
            throw new common_1.NotFoundException('Order not found');
        return result;
    }
    async assignMaster(id, body) {
        return this.orders.assignMaster(id, body ?? {});
    }
    async cancel(id, req) {
        const user = req.user;
        const orgId = user?.organizationId;
        const clientMode = (0, request_app_util_1.isClientAppRequest)(req);
        let result;
        if (!clientMode && orgId) {
            result = await this.orders.cancel(id, { organizationId: orgId });
        }
        else {
            const phone = user?.phone ? String(user.phone).replace(/\D/g, '') : '';
            if (!phone)
                throw new common_1.BadRequestException('Нет доступа к отмене заказа');
            result = await this.orders.cancel(id, { clientPhone: phone });
        }
        if (!result)
            throw new common_1.NotFoundException('Заказ не найден или нет прав на отмену');
        return result;
    }
    async approveByClient(id, req, body) {
        const approvedIds = body?.approved_item_ids ?? [];
        const rejectedIds = body?.rejected_item_ids ?? [];
        const approvalMessageId = body?.approval_message_id;
        console.log('[approval] POST approval', {
            orderId: id,
            approved_item_ids: approvedIds,
            rejected_item_ids: rejectedIds,
            approval_message_id: approvalMessageId ?? null,
        });
        const user = req.user;
        if (!(0, request_app_util_1.isClientAppRequest)(req) && user?.organizationId) {
            throw new common_1.BadRequestException('Только клиент может согласовать доп. работы');
        }
        const phone = user?.phone ? String(user.phone).replace(/\D/g, '') : '';
        if (!phone)
            throw new common_1.BadRequestException('Нет номера телефона');
        const order = await this.orders.approveByClient(id, phone, approvedIds, rejectedIds, {
            approvalMessageId,
        });
        if (!order)
            throw new common_1.BadRequestException('Не удалось согласовать. Проверьте, что заказ ожидает согласования и принадлежит вам.');
        return order;
    }
    async confirmByClient(id, req, body) {
        const user = req.user;
        if (!(0, request_app_util_1.isClientAppRequest)(req) && user?.organizationId) {
            throw new common_1.BadRequestException('Только клиент может подтвердить заказ');
        }
        const phone = user?.phone ? String(user.phone).replace(/\D/g, '') : '';
        if (!phone)
            throw new common_1.BadRequestException('Нет номера телефона');
        const order = await this.orders.confirmByClient(id, phone, body?.date_time, body?.accept_proposed, body?.approval_message_id);
        if (!order)
            throw new common_1.BadRequestException('Не удалось подтвердить заказ. Проверьте, что заказ ожидает согласования и принадлежит вам.');
        return order;
    }
    async confirmByPhone(id, req) {
        const orgId = req.user?.organizationId;
        if (!orgId)
            throw new common_1.BadRequestException('Доступно только для организации');
        const order = await this.orders.approveBySto(id, orgId);
        if (!order)
            throw new common_1.BadRequestException('Заказ не найден, не в ожидании согласования или не принадлежит вашей организации.');
        console.log('[confirm-by-phone] orderId=' + id + ', newStatus=' + order.status + ', system message sent');
        return order;
    }
    async updateItems(id, items, req) {
        const organizationId = req.user?.organizationId ?? undefined;
        return this.orders.updateItems(id, items ?? [], organizationId);
    }
    async getChatForOrder(id, req) {
        const user = req.user;
        const orgId = user?.organizationId;
        const phone = user?.phone;
        if ((0, request_app_util_1.isClientAppRequest)(req)) {
            if (phone != null && String(phone).trim() !== '') {
                return this.orders.getChatForOrder(id, { clientPhone: String(phone) });
            }
            throw new common_1.BadRequestException('Требуется авторизация клиента');
        }
        if (orgId)
            return this.orders.getChatForOrder(id, { organizationId: orgId });
        if (phone != null && String(phone).trim() !== '')
            return this.orders.getChatForOrder(id, { clientPhone: String(phone) });
        throw new common_1.BadRequestException('Требуется авторизация организации или клиента');
    }
};
exports.OrdersController = OrdersController;
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "list", null);
__decorate([
    (0, common_1.Get)(':orderId/photos'),
    __param(0, (0, common_1.Param)('orderId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "getPhotos", null);
__decorate([
    (0, common_1.Post)(':orderId/photos'),
    (0, common_2.UseInterceptors)((0, platform_express_1.FileInterceptor)('file')),
    __param(0, (0, common_1.Param)('orderId')),
    __param(1, (0, common_2.UploadedFile)()),
    __param(2, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "addPhoto", null);
__decorate([
    (0, common_1.Get)(':orderId/photos/:photoId/file'),
    __param(0, (0, common_1.Param)('orderId')),
    __param(1, (0, common_1.Param)('photoId')),
    __param(2, (0, common_1.Res)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, Object]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "getPhotoFile", null);
__decorate([
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "get", null);
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "create", null);
__decorate([
    (0, common_1.Post)('clear-all'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "clearAll", null);
__decorate([
    (0, common_1.Patch)(':id/status'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)('status')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "updateStatus", null);
__decorate([
    (0, common_1.Patch)(':id/time'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "updateTime", null);
__decorate([
    (0, common_1.Post)(':id/assign-master'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "assignMaster", null);
__decorate([
    (0, common_1.Post)(':id/cancel'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "cancel", null);
__decorate([
    (0, common_1.Post)(':id/approval'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "approveByClient", null);
__decorate([
    (0, common_1.Post)(':id/confirm'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "confirmByClient", null);
__decorate([
    (0, common_1.Post)(':id/confirm-by-phone'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "confirmByPhone", null);
__decorate([
    (0, common_1.Patch)(':id/items'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)('items')),
    __param(2, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Array, Object]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "updateItems", null);
__decorate([
    (0, common_1.Get)(':id/chat'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], OrdersController.prototype, "getChatForOrder", null);
exports.OrdersController = OrdersController = __decorate([
    (0, common_1.Controller)('orders'),
    (0, common_1.UseGuards)((0, passport_1.AuthGuard)('jwt')),
    __metadata("design:paramtypes", [orders_service_1.OrdersService])
], OrdersController);
//# sourceMappingURL=orders.controller.js.map