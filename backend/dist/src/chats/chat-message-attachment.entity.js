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
exports.ChatMessageAttachment = void 0;
const typeorm_1 = require("typeorm");
const chat_message_entity_1 = require("./chat-message.entity");
const media_asset_entity_1 = require("../media/media-asset.entity");
let ChatMessageAttachment = class ChatMessageAttachment {
};
exports.ChatMessageAttachment = ChatMessageAttachment;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], ChatMessageAttachment.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'message_id', type: 'uuid' }),
    __metadata("design:type", String)
], ChatMessageAttachment.prototype, "messageId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => chat_message_entity_1.ChatMessage, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'message_id' }),
    __metadata("design:type", chat_message_entity_1.ChatMessage)
], ChatMessageAttachment.prototype, "message", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'media_asset_id', type: 'uuid', unique: true }),
    __metadata("design:type", String)
], ChatMessageAttachment.prototype, "mediaAssetId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => media_asset_entity_1.MediaAsset, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'media_asset_id' }),
    __metadata("design:type", media_asset_entity_1.MediaAsset)
], ChatMessageAttachment.prototype, "mediaAsset", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'sort_order', type: 'int', default: 0 }),
    __metadata("design:type", Number)
], ChatMessageAttachment.prototype, "sortOrder", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at', type: 'timestamptz' }),
    __metadata("design:type", Date)
], ChatMessageAttachment.prototype, "createdAt", void 0);
exports.ChatMessageAttachment = ChatMessageAttachment = __decorate([
    (0, typeorm_1.Entity)('chat_message_attachments')
], ChatMessageAttachment);
//# sourceMappingURL=chat-message-attachment.entity.js.map