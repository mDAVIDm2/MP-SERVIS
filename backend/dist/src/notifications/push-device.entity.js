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
exports.PushDevice = void 0;
const typeorm_1 = require("typeorm");
const user_entity_1 = require("../users/user.entity");
let PushDevice = class PushDevice {
};
exports.PushDevice = PushDevice;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], PushDevice.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'user_id' }),
    __metadata("design:type", String)
], PushDevice.prototype, "userId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => user_entity_1.User, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'user_id' }),
    __metadata("design:type", user_entity_1.User)
], PushDevice.prototype, "user", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'device_token' }),
    __metadata("design:type", String)
], PushDevice.prototype, "deviceToken", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 20, default: 'android' }),
    __metadata("design:type", String)
], PushDevice.prototype, "platform", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'fcm_app', type: 'varchar', length: 16, default: 'client' }),
    __metadata("design:type", String)
], PushDevice.prototype, "fcmApp", void 0);
exports.PushDevice = PushDevice = __decorate([
    (0, typeorm_1.Entity)('push_devices')
], PushDevice);
//# sourceMappingURL=push-device.entity.js.map