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
exports.InternalClientCarsController = void 0;
const common_1 = require("@nestjs/common");
const internal_jwt_guard_1 = require("./internal-jwt.guard");
const orders_service_1 = require("../orders/orders.service");
const client_cars_service_1 = require("../users/client-cars.service");
const users_service_1 = require("../users/users.service");
let InternalClientCarsController = class InternalClientCarsController {
    constructor(orders, clientCars, users) {
        this.orders = orders;
        this.clientCars = clientCars;
        this.users = users;
    }
    async list() {
        const agg = await this.orders.listClientCarsAggregatedForInternal();
        await this.clientCars.enrichAggregatedClientCarsWithGaragePhotos(agg.items);
        return agg;
    }
    async moderateClear(body) {
        const r = await this.orders.moderateClearCarFieldsForInternal(body.client_phone, body.car_id, {
            vin: body.vin === true,
            license_plate: body.license_plate === true,
            car_info: body.car_info === true,
            car_photo_url: body.car_photo_url === true,
        });
        return { ok: true, ...r };
    }
    async hideFromClient(body) {
        const phone = String(body?.client_phone ?? '').trim();
        const carId = String(body?.car_id ?? '').trim();
        if (!phone || !carId)
            throw new common_1.BadRequestException('Укажите client_phone и car_id');
        const norm = this.orders.normalizePhoneForCompare(phone);
        const userId = await this.users.findIdByNormalizedPhone(norm, 'client');
        if (!userId)
            throw new common_1.BadRequestException('Клиентский аккаунт с таким телефоном не найден');
        await this.clientCars.hideCarFromClientForInternal(userId, carId, phone);
        return { ok: true };
    }
    async restoreForClient(body) {
        const phone = String(body?.client_phone ?? '').trim();
        const carId = String(body?.car_id ?? '').trim();
        if (!phone || !carId)
            throw new common_1.BadRequestException('Укажите client_phone и car_id');
        const norm = this.orders.normalizePhoneForCompare(phone);
        const userId = await this.users.findIdByNormalizedPhone(norm, 'client');
        if (!userId)
            throw new common_1.BadRequestException('Клиентский аккаунт с таким телефоном не найден');
        await this.clientCars.restoreCarForClientForInternal(userId, carId, phone);
        return { ok: true };
    }
    async hardDelete(body) {
        if (body?.confirm !== 'DELETE') {
            throw new common_1.BadRequestException('Для подтверждения укажите confirm со значением DELETE');
        }
        const phone = String(body?.client_phone ?? '').trim();
        const carId = String(body?.car_id ?? '').trim();
        if (!phone || !carId)
            throw new common_1.BadRequestException('Укажите client_phone и car_id');
        const norm = this.orders.normalizePhoneForCompare(phone);
        const userId = await this.users.findIdByNormalizedPhone(norm, 'client');
        if (!userId)
            throw new common_1.BadRequestException('Клиентский аккаунт с таким телефоном не найден');
        await this.clientCars.assertCarLinkedToClientUserForInternal(userId, carId, phone);
        const purge = await this.orders.purgeOrdersByCarIdForInternal(carId);
        await this.clientCars.eraseCarAfterHardDeleteForInternal(carId);
        return { ok: true, ...purge };
    }
    async history(clientPhone, carId) {
        const phone = String(clientPhone || '').trim();
        const cid = String(carId || '').trim();
        if (!phone || !cid)
            return { items: [] };
        const items = await this.orders.findOrdersByCarForInternal(phone, cid);
        return { items };
    }
    async carPhotoFile(carId, filename, res) {
        const car = await this.clientCars.findCarEntityById(carId);
        if (!car)
            throw new common_1.NotFoundException();
        const fp = this.clientCars.getCarPhotoFilePath(car.userId, carId, filename);
        if (!fp)
            throw new common_1.NotFoundException();
        res.setHeader('Cache-Control', 'private, no-store, no-cache, must-revalidate');
        return res.sendFile(fp);
    }
};
exports.InternalClientCarsController = InternalClientCarsController;
__decorate([
    (0, common_1.Get)(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], InternalClientCarsController.prototype, "list", null);
__decorate([
    (0, common_1.Post)('moderate-clear'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], InternalClientCarsController.prototype, "moderateClear", null);
__decorate([
    (0, common_1.Post)('hide-from-client'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], InternalClientCarsController.prototype, "hideFromClient", null);
__decorate([
    (0, common_1.Post)('restore-for-client'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], InternalClientCarsController.prototype, "restoreForClient", null);
__decorate([
    (0, common_1.Post)('hard-delete'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], InternalClientCarsController.prototype, "hardDelete", null);
__decorate([
    (0, common_1.Get)('history'),
    __param(0, (0, common_1.Query)('client_phone')),
    __param(1, (0, common_1.Query)('car_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", Promise)
], InternalClientCarsController.prototype, "history", null);
__decorate([
    (0, common_1.Get)('photo-file/:carId/:filename'),
    __param(0, (0, common_1.Param)('carId')),
    __param(1, (0, common_1.Param)('filename')),
    __param(2, (0, common_1.Res)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, Object]),
    __metadata("design:returntype", Promise)
], InternalClientCarsController.prototype, "carPhotoFile", null);
exports.InternalClientCarsController = InternalClientCarsController = __decorate([
    (0, common_1.Controller)('internal/client-cars'),
    (0, common_1.UseGuards)(internal_jwt_guard_1.InternalJwtAuthGuard),
    __metadata("design:paramtypes", [orders_service_1.OrdersService,
        client_cars_service_1.ClientCarsService,
        users_service_1.UsersService])
], InternalClientCarsController);
//# sourceMappingURL=internal-client-cars.controller.js.map