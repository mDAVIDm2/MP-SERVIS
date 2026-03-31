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
let InternalClientCarsController = class InternalClientCarsController {
    constructor(orders) {
        this.orders = orders;
    }
    async list() {
        return this.orders.listClientCarsAggregatedForInternal();
    }
    async history(clientPhone, carId) {
        const phone = String(clientPhone || '').trim();
        const cid = String(carId || '').trim();
        if (!phone || !cid)
            return { items: [] };
        const items = await this.orders.findOrdersByCarForInternal(phone, cid);
        return { items };
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
    (0, common_1.Get)('history'),
    __param(0, (0, common_1.Query)('client_phone')),
    __param(1, (0, common_1.Query)('car_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", Promise)
], InternalClientCarsController.prototype, "history", null);
exports.InternalClientCarsController = InternalClientCarsController = __decorate([
    (0, common_1.Controller)('internal/client-cars'),
    (0, common_1.UseGuards)(internal_jwt_guard_1.InternalJwtAuthGuard),
    __metadata("design:paramtypes", [orders_service_1.OrdersService])
], InternalClientCarsController);
//# sourceMappingURL=internal-client-cars.controller.js.map