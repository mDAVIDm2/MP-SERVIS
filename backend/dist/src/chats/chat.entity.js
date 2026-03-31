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
exports.Chat = void 0;
const typeorm_1 = require("typeorm");
const chat_message_entity_1 = require("./chat-message.entity");
const order_entity_1 = require("../orders/order.entity");
let Chat = class Chat {
};
exports.Chat = Chat;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], Chat.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'order_id', type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], Chat.prototype, "lastOrderId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => order_entity_1.Order, { onDelete: 'SET NULL' }),
    (0, typeorm_1.JoinColumn)({ name: 'order_id' }),
    __metadata("design:type", Object)
], Chat.prototype, "order", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'organization_id', type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], Chat.prototype, "organizationId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'client_phone', type: 'varchar', length: 32, nullable: true }),
    __metadata("design:type", Object)
], Chat.prototype, "clientPhone", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'client_last_read_at', type: 'timestamptz', nullable: true }),
    __metadata("design:type", Object)
], Chat.prototype, "clientLastReadAt", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'organization_last_read_at', type: 'timestamptz', nullable: true }),
    __metadata("design:type", Object)
], Chat.prototype, "organizationLastReadAt", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'internal_support_last_read_at', type: 'timestamptz', nullable: true }),
    __metadata("design:type", Object)
], Chat.prototype, "internalSupportLastReadAt", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => chat_message_entity_1.ChatMessage, (m) => m.chat, { cascade: true }),
    __metadata("design:type", Array)
], Chat.prototype, "messages", void 0);
exports.Chat = Chat = __decorate([
    (0, typeorm_1.Entity)('chats'),
    (0, typeorm_1.Index)('IDX_chats_org_client_phone', ['organizationId', 'clientPhone'])
], Chat);
//# sourceMappingURL=chat.entity.js.map