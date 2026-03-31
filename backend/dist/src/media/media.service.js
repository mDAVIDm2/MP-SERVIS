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
exports.MediaService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const crypto_1 = require("crypto");
const media_asset_entity_1 = require("./media-asset.entity");
const order_media_entity_1 = require("./order-media.entity");
const chat_message_attachment_entity_1 = require("../chats/chat-message-attachment.entity");
const local_storage_service_1 = require("./local-storage.service");
const order_image_processor_1 = require("./order-image.processor");
let MediaService = class MediaService {
    constructor(assetRepo, orderMediaRepo, chatMsgAttRepo, storage) {
        this.assetRepo = assetRepo;
        this.orderMediaRepo = orderMediaRepo;
        this.chatMsgAttRepo = chatMsgAttRepo;
        this.storage = storage;
    }
    async countOrderMediaLinks(orderId) {
        return this.orderMediaRepo.count({ where: { orderId } });
    }
    async attachOrderImage(params) {
        const { orderId, organizationId, file, uploadedByUserId } = params;
        const mime = String(file.mimetype || '').toLowerCase().split(';')[0].trim();
        if (!order_image_processor_1.ALLOWED_ORDER_IMAGE_MIMES.has(mime)) {
            throw new common_1.BadRequestException('Допустимы только изображения JPEG, PNG или WebP.');
        }
        const raw = file.buffer?.length ? file.buffer : null;
        if (!raw || raw.length === 0) {
            throw new common_1.BadRequestException('Пустой файл');
        }
        if (raw.length > order_image_processor_1.MAX_ORDER_IMAGE_UPLOAD_BYTES) {
            throw new common_1.BadRequestException('Файл слишком большой (максимум 25 МБ до сжатия).');
        }
        let processed;
        try {
            processed = await (0, order_image_processor_1.processOrderImageUpload)(raw);
        }
        catch {
            throw new common_1.BadRequestException('Не удалось обработать изображение. Загрузите другой файл.');
        }
        const storageKey = `${organizationId}/orders/${orderId}/${(0, crypto_1.randomUUID)()}.webp`;
        await this.storage.putObject(storageKey, processed.buffer);
        const asset = this.assetRepo.create({
            organizationId,
            chatId: null,
            uploadedByUserId: uploadedByUserId ?? null,
            mediaType: 'image',
            mimeType: processed.mimeType,
            storageProvider: 'local',
            storageKey,
            originalFilename: file.originalname?.slice(0, 255) ?? null,
            sizeBytes: processed.buffer.length,
            width: processed.width,
            height: processed.height,
            durationSec: null,
            status: 'ready',
        });
        await this.assetRepo.save(asset);
        const link = this.orderMediaRepo.create({
            orderId,
            mediaAssetId: asset.id,
            sortOrder: 0,
        });
        await this.orderMediaRepo.save(link);
        return {
            id: asset.id,
            storage_key: asset.storageKey,
            size_bytes: asset.sizeBytes,
            width: asset.width,
            height: asset.height,
            created_at: asset.createdAt.toISOString(),
        };
    }
    async getLocalFilePathForOrderPhoto(orderId, photoId) {
        const link = await this.orderMediaRepo.findOne({
            where: { orderId, mediaAssetId: photoId },
            relations: ['mediaAsset'],
        });
        if (!link?.mediaAsset)
            return null;
        if (link.mediaAsset.storageProvider !== 'local')
            return null;
        return this.storage.getAbsolutePath(link.mediaAsset.storageKey);
    }
    async listOrderMediaForApi(orderId, baseUrl) {
        const rows = await this.orderMediaRepo.find({
            where: { orderId },
            relations: ['mediaAsset'],
            order: { createdAt: 'ASC' },
        });
        return rows.map((r) => {
            const a = r.mediaAsset;
            return {
                id: a.id,
                file_path: a.storageKey,
                url: `${baseUrl}/orders/${orderId}/photos/${a.id}/file`,
                created_at: a.createdAt.toISOString(),
                media_type: a.mediaType,
                size_bytes: a.sizeBytes,
                width: a.width,
                height: a.height,
            };
        });
    }
    async purgeMediaForOrders(orderIds) {
        if (orderIds.length === 0)
            return { deleted_assets: 0 };
        const links = await this.orderMediaRepo.find({
            where: { orderId: (0, typeorm_2.In)(orderIds) },
            relations: ['mediaAsset'],
        });
        const seen = new Set();
        for (const l of links) {
            const a = l.mediaAsset;
            if (!a || seen.has(a.id))
                continue;
            seen.add(a.id);
            await this.storage.deleteObject(a.storageKey);
        }
        const assetIds = [...seen];
        if (assetIds.length === 0)
            return { deleted_assets: 0 };
        const result = await this.assetRepo.delete({ id: (0, typeorm_2.In)(assetIds) });
        return { deleted_assets: result.affected ?? 0 };
    }
    async addImagesToChatMessage(params) {
        const { messageId, chatId, organizationId, files, uploadedByUserId } = params;
        let sortOrder = 0;
        for (const file of files) {
            const mime = String(file.mimetype || '').toLowerCase().split(';')[0].trim();
            if (!order_image_processor_1.ALLOWED_ORDER_IMAGE_MIMES.has(mime)) {
                throw new common_1.BadRequestException('Допустимы только изображения JPEG, PNG или WebP.');
            }
            const raw = file.buffer?.length ? file.buffer : null;
            if (!raw || raw.length === 0) {
                throw new common_1.BadRequestException('Пустой файл');
            }
            if (raw.length > order_image_processor_1.MAX_ORDER_IMAGE_UPLOAD_BYTES) {
                throw new common_1.BadRequestException('Файл слишком большой (максимум 25 МБ до сжатия).');
            }
            let processed;
            try {
                processed = await (0, order_image_processor_1.processOrderImageUpload)(raw);
            }
            catch {
                throw new common_1.BadRequestException('Не удалось обработать изображение. Загрузите другой файл.');
            }
            const prefix = organizationId != null && organizationId !== ''
                ? `${organizationId}/chats/${chatId}`
                : `support/chats/${chatId}`;
            const storageKey = `${prefix}/${(0, crypto_1.randomUUID)()}.webp`;
            await this.storage.putObject(storageKey, processed.buffer);
            const asset = this.assetRepo.create({
                organizationId: organizationId ?? null,
                chatId,
                uploadedByUserId: uploadedByUserId ?? null,
                mediaType: 'image',
                mimeType: processed.mimeType,
                storageProvider: 'local',
                storageKey,
                originalFilename: file.originalname?.slice(0, 255) ?? null,
                sizeBytes: processed.buffer.length,
                width: processed.width,
                height: processed.height,
                durationSec: null,
                status: 'ready',
            });
            await this.assetRepo.save(asset);
            const link = this.chatMsgAttRepo.create({
                messageId,
                mediaAssetId: asset.id,
                sortOrder: sortOrder++,
            });
            await this.chatMsgAttRepo.save(link);
        }
    }
    async getLocalPathForChatAttachment(chatId, assetId) {
        const asset = await this.assetRepo.findOne({ where: { id: assetId, chatId } });
        if (!asset || asset.storageProvider !== 'local')
            return null;
        return this.storage.getAbsolutePath(asset.storageKey);
    }
    async getChatAttachmentDtosByMessageIds(chatId, messageIds, baseUrl) {
        const map = new Map();
        if (messageIds.length === 0)
            return map;
        const rows = await this.chatMsgAttRepo.find({
            where: { messageId: (0, typeorm_2.In)(messageIds) },
            relations: ['mediaAsset'],
            order: { sortOrder: 'ASC' },
        });
        for (const r of rows) {
            const a = r.mediaAsset;
            if (!a || a.chatId !== chatId)
                continue;
            const dto = {
                id: a.id,
                url: `${baseUrl}/chats/${chatId}/attachments/${a.id}/file`,
                mime_type: a.mimeType,
                width: a.width,
                height: a.height,
                size_bytes: a.sizeBytes,
            };
            if (!map.has(r.messageId))
                map.set(r.messageId, []);
            map.get(r.messageId).push(dto);
        }
        return map;
    }
};
exports.MediaService = MediaService;
exports.MediaService = MediaService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(media_asset_entity_1.MediaAsset)),
    __param(1, (0, typeorm_1.InjectRepository)(order_media_entity_1.OrderMedia)),
    __param(2, (0, typeorm_1.InjectRepository)(chat_message_attachment_entity_1.ChatMessageAttachment)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        local_storage_service_1.LocalStorageService])
], MediaService);
//# sourceMappingURL=media.service.js.map