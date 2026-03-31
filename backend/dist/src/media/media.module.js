"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.MediaModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const media_asset_entity_1 = require("./media-asset.entity");
const order_media_entity_1 = require("./order-media.entity");
const chat_message_attachment_entity_1 = require("../chats/chat-message-attachment.entity");
const local_storage_service_1 = require("./local-storage.service");
const media_service_1 = require("./media.service");
let MediaModule = class MediaModule {
};
exports.MediaModule = MediaModule;
exports.MediaModule = MediaModule = __decorate([
    (0, common_1.Module)({
        imports: [typeorm_1.TypeOrmModule.forFeature([media_asset_entity_1.MediaAsset, order_media_entity_1.OrderMedia, chat_message_attachment_entity_1.ChatMessageAttachment])],
        providers: [local_storage_service_1.LocalStorageService, media_service_1.MediaService],
        exports: [media_service_1.MediaService, local_storage_service_1.LocalStorageService],
    })
], MediaModule);
//# sourceMappingURL=media.module.js.map