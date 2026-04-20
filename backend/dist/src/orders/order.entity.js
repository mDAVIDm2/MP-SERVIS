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
Object.defineProperty(exports, "__esModule", { value: true });
exports.Order = void 0;
const typeorm_1 = require("typeorm");
const organization_entity_1 = require("../organizations/organization.entity");
const staff_member_entity_1 = require("../organizations/staff-member.entity");
const order_item_entity_1 = require("./order-item.entity");
let Order = class Order {
};
exports.Order = Order;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], Order.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'order_number', unique: true }),
    __metadata("design:type", String)
], Order.prototype, "orderNumber", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'car_id' }),
    __metadata("design:type", String)
], Order.prototype, "carId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'car_info', default: '' }),
    __metadata("design:type", String)
], Order.prototype, "carInfo", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'car_photo_url', type: 'varchar', length: 1024, nullable: true }),
    __metadata("design:type", Object)
], Order.prototype, "carPhotoUrl", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'vin', type: 'varchar', length: 32, nullable: true }),
    __metadata("design:type", Object)
], Order.prototype, "vin", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'license_plate', type: 'varchar', length: 20, nullable: true }),
    __metadata("design:type", Object)
], Order.prototype, "licensePlate", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'body_type', type: 'varchar', length: 64, nullable: true }),
    __metadata("design:type", Object)
], Order.prototype, "bodyType", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'color', type: 'varchar', length: 64, nullable: true }),
    __metadata("design:type", Object)
], Order.prototype, "color", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'mileage', type: 'int', nullable: true }),
    __metadata("design:type", Object)
], Order.prototype, "mileage", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'engine_type', type: 'varchar', length: 64, nullable: true }),
    __metadata("design:type", Object)
], Order.prototype, "engineType", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'client_name', type: 'varchar', length: 255, nullable: true }),
    __metadata("design:type", Object)
], Order.prototype, "clientName", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'client_phone', type: 'varchar', length: 32, nullable: true }),
    __metadata("design:type", Object)
], Order.prototype, "clientPhone", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 30, default: 'pending_confirmation' }),
    __metadata("design:type", String)
], Order.prototype, "status", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'previous_status', type: 'varchar', length: 30, nullable: true }),
    __metadata("design:type", Object)
], Order.prototype, "previousStatus", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'first_confirmed_at', type: 'timestamptz', nullable: true }),
    __metadata("design:type", Object)
], Order.prototype, "firstConfirmedAt", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'date_time', type: 'timestamptz' }),
    __metadata("design:type", Date)
], Order.prototype, "dateTime", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'planned_start_time', type: 'timestamptz', nullable: true }),
    __metadata("design:type", Object)
], Order.prototype, "plannedStartTime", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'planned_end_time', type: 'timestamptz', nullable: true }),
    __metadata("design:type", Object)
], Order.prototype, "plannedEndTime", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'actual_start_time', type: 'timestamptz', nullable: true }),
    __metadata("design:type", Object)
], Order.prototype, "actualStartTime", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'actual_end_time', type: 'timestamptz', nullable: true }),
    __metadata("design:type", Object)
], Order.prototype, "actualEndTime", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 500, nullable: true }),
    __metadata("design:type", Object)
], Order.prototype, "comment", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'master_id', type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], Order.prototype, "masterId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'bay_id', type: 'varchar', length: 64, nullable: true }),
    __metadata("design:type", Object)
], Order.prototype, "bayId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'organization_id' }),
    __metadata("design:type", String)
], Order.prototype, "organizationId", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], Order.prototype, "createdAt", void 0);
__decorate([
    (0, typeorm_1.UpdateDateColumn)({ name: 'updated_at' }),
    __metadata("design:type", Date)
], Order.prototype, "updatedAt", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => organization_entity_1.Organization, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'organization_id' }),
    __metadata("design:type", organization_entity_1.Organization)
], Order.prototype, "organization", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => staff_member_entity_1.StaffMember, { nullable: true, onDelete: 'SET NULL' }),
    (0, typeorm_1.JoinColumn)({ name: 'master_id' }),
    __metadata("design:type", Object)
], Order.prototype, "master", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => order_item_entity_1.OrderItem, (i) => i.order, { cascade: true }),
    __metadata("design:type", Array)
], Order.prototype, "items", void 0);
exports.Order = Order = __decorate([
    (0, typeorm_1.Entity)('orders')
], Order);
//# sourceMappingURL=order.entity.js.map