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
exports.ChatMessage = void 0;
const typeorm_1 = require("typeorm");
const chat_entity_1 = require("./chat.entity");
let ChatMessage = class ChatMessage {
};
exports.ChatMessage = ChatMessage;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], ChatMessage.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'chat_id' }),
    __metadata("design:type", String)
], ChatMessage.prototype, "chatId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => chat_entity_1.Chat, (c) => c.messages, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'chat_id' }),
    __metadata("design:type", chat_entity_1.Chat)
], ChatMessage.prototype, "chat", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'text', default: '' }),
    __metadata("design:type", String)
], ChatMessage.prototype, "text", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'is_from_client', default: false }),
    __metadata("design:type", Boolean)
], ChatMessage.prototype, "isFromClient", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'is_from_support_operator', default: false }),
    __metadata("design:type", Boolean)
], ChatMessage.prototype, "isFromSupportOperator", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'support_channel', type: 'varchar', length: 16, nullable: true }),
    __metadata("design:type", Object)
], ChatMessage.prototype, "supportChannel", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'is_system', default: false }),
    __metadata("design:type", Boolean)
], ChatMessage.prototype, "isSystem", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'timestamptz', default: () => 'CURRENT_TIMESTAMP' }),
    __metadata("design:type", Date)
], ChatMessage.prototype, "at", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'approval_items', type: 'jsonb', nullable: true }),
    __metadata("design:type", Object)
], ChatMessage.prototype, "approvalItems", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'approval_status', type: 'varchar', length: 20, nullable: true }),
    __metadata("design:type", Object)
], ChatMessage.prototype, "approvalStatus", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'proposed_date_time', type: 'timestamptz', nullable: true }),
    __metadata("design:type", Object)
], ChatMessage.prototype, "proposedDateTime", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'order_id', type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], ChatMessage.prototype, "orderId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'message_type', type: 'varchar', length: 32, nullable: true }),
    __metadata("design:type", Object)
], ChatMessage.prototype, "messageType", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'order_items_snapshot', type: 'jsonb', nullable: true }),
    __metadata("design:type", Object)
], ChatMessage.prototype, "orderItemsSnapshot", void 0);
exports.ChatMessage = ChatMessage = __decorate([
    (0, typeorm_1.Entity)('chat_messages')
], ChatMessage);
//# sourceMappingURL=chat-message.entity.js.map