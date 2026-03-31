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
exports.MediaAsset = void 0;
const typeorm_1 = require("typeorm");
const organization_entity_1 = require("../organizations/organization.entity");
const user_entity_1 = require("../users/user.entity");
const chat_entity_1 = require("../chats/chat.entity");
let MediaAsset = class MediaAsset {
};
exports.MediaAsset = MediaAsset;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], MediaAsset.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'organization_id', type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], MediaAsset.prototype, "organizationId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => organization_entity_1.Organization, { onDelete: 'CASCADE', nullable: true }),
    (0, typeorm_1.JoinColumn)({ name: 'organization_id' }),
    __metadata("design:type", Object)
], MediaAsset.prototype, "organization", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'chat_id', type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], MediaAsset.prototype, "chatId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => chat_entity_1.Chat, { onDelete: 'CASCADE', nullable: true }),
    (0, typeorm_1.JoinColumn)({ name: 'chat_id' }),
    __metadata("design:type", Object)
], MediaAsset.prototype, "chat", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'uploaded_by_user_id', type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], MediaAsset.prototype, "uploadedByUserId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => user_entity_1.User, { onDelete: 'SET NULL', nullable: true }),
    (0, typeorm_1.JoinColumn)({ name: 'uploaded_by_user_id' }),
    __metadata("design:type", Object)
], MediaAsset.prototype, "uploadedByUser", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'media_type', type: 'varchar', length: 16 }),
    __metadata("design:type", String)
], MediaAsset.prototype, "mediaType", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'mime_type', type: 'varchar', length: 128 }),
    __metadata("design:type", String)
], MediaAsset.prototype, "mimeType", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'storage_provider', type: 'varchar', length: 16, default: 'local' }),
    __metadata("design:type", String)
], MediaAsset.prototype, "storageProvider", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'storage_key', type: 'varchar', length: 512, unique: true }),
    __metadata("design:type", String)
], MediaAsset.prototype, "storageKey", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'original_filename', type: 'varchar', length: 255, nullable: true }),
    __metadata("design:type", Object)
], MediaAsset.prototype, "originalFilename", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'size_bytes', type: 'int', default: 0 }),
    __metadata("design:type", Number)
], MediaAsset.prototype, "sizeBytes", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'width', type: 'int', nullable: true }),
    __metadata("design:type", Object)
], MediaAsset.prototype, "width", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'height', type: 'int', nullable: true }),
    __metadata("design:type", Object)
], MediaAsset.prototype, "height", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'duration_sec', type: 'int', nullable: true }),
    __metadata("design:type", Object)
], MediaAsset.prototype, "durationSec", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 16, default: 'ready' }),
    __metadata("design:type", String)
], MediaAsset.prototype, "status", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at', type: 'timestamptz' }),
    __metadata("design:type", Date)
], MediaAsset.prototype, "createdAt", void 0);
exports.MediaAsset = MediaAsset = __decorate([
    (0, typeorm_1.Entity)('media_assets')
], MediaAsset);
//# sourceMappingURL=media-asset.entity.js.map