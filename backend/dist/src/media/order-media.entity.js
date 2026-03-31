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
exports.OrderMedia = void 0;
const typeorm_1 = require("typeorm");
const order_entity_1 = require("../orders/order.entity");
const media_asset_entity_1 = require("./media-asset.entity");
let OrderMedia = class OrderMedia {
};
exports.OrderMedia = OrderMedia;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], OrderMedia.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'order_id', type: 'uuid' }),
    __metadata("design:type", String)
], OrderMedia.prototype, "orderId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => order_entity_1.Order, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'order_id' }),
    __metadata("design:type", order_entity_1.Order)
], OrderMedia.prototype, "order", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'media_asset_id', type: 'uuid', unique: true }),
    __metadata("design:type", String)
], OrderMedia.prototype, "mediaAssetId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => media_asset_entity_1.MediaAsset, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'media_asset_id' }),
    __metadata("design:type", media_asset_entity_1.MediaAsset)
], OrderMedia.prototype, "mediaAsset", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'sort_order', type: 'int', default: 0 }),
    __metadata("design:type", Number)
], OrderMedia.prototype, "sortOrder", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at', type: 'timestamptz' }),
    __metadata("design:type", Date)
], OrderMedia.prototype, "createdAt", void 0);
exports.OrderMedia = OrderMedia = __decorate([
    (0, typeorm_1.Entity)('order_media')
], OrderMedia);
//# sourceMappingURL=order-media.entity.js.map