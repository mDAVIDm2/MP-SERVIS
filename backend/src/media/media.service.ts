import { BadRequestException, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { randomUUID } from 'crypto';
import { MediaAsset } from './media-asset.entity';
import { OrderMedia } from './order-media.entity';
import { ChatMessageAttachment } from '../chats/chat-message-attachment.entity';
import { LocalStorageService } from './local-storage.service';
import {
  ALLOWED_ORDER_IMAGE_MIMES,
  MAX_ORDER_IMAGE_UPLOAD_BYTES,
  processOrderImageUpload,
  resolveOrderUploadMime,
} from './order-image.processor';

@Injectable()
export class MediaService {
  constructor(
    @InjectRepository(MediaAsset) private readonly assetRepo: Repository<MediaAsset>,
    @InjectRepository(OrderMedia) private readonly orderMediaRepo: Repository<OrderMedia>,
    @InjectRepository(ChatMessageAttachment)
    private readonly chatMsgAttRepo: Repository<ChatMessageAttachment>,
    private readonly storage: LocalStorageService,
  ) {}

  async countOrderMediaLinks(orderId: string): Promise<number> {
    return this.orderMediaRepo.count({ where: { orderId } });
  }

  /**
   * Сохранить сжатое изображение и привязать к заказу. Возвращает id = media_asset.id (в URL /photos/:id/file).
   */
  async attachOrderImage(params: {
    orderId: string;
    organizationId: string;
    file: Express.Multer.File;
    uploadedByUserId?: string | null;
  }): Promise<{
    id: string;
    storage_key: string;
    size_bytes: number;
    width: number | null;
    height: number | null;
    created_at: string;
  }> {
    const { orderId, organizationId, file, uploadedByUserId } = params;
    const raw = file.buffer?.length ? file.buffer : null;
    if (!raw || raw.length === 0) {
      throw new BadRequestException('Пустой файл');
    }
    if (raw.length > MAX_ORDER_IMAGE_UPLOAD_BYTES) {
      throw new BadRequestException('Файл слишком большой (максимум 25 МБ до сжатия).');
    }
    const mime = resolveOrderUploadMime(file.mimetype, file.originalname, raw);
    if (!ALLOWED_ORDER_IMAGE_MIMES.has(mime)) {
      throw new BadRequestException('Допустимы только изображения JPEG, PNG, WebP, HEIC.');
    }

    let processed;
    try {
      processed = await processOrderImageUpload(raw);
    } catch {
      throw new BadRequestException('Не удалось обработать изображение. Загрузите другой файл.');
    }

    const storageKey = `${organizationId}/orders/${orderId}/${randomUUID()}.webp`;
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

  async getLocalFilePathForOrderPhoto(orderId: string, photoId: string): Promise<string | null> {
    const link = await this.orderMediaRepo.findOne({
      where: { orderId, mediaAssetId: photoId },
      relations: ['mediaAsset'],
    });
    if (!link?.mediaAsset) return null;
    if (link.mediaAsset.storageProvider !== 'local') return null;
    return this.storage.getAbsolutePath(link.mediaAsset.storageKey);
  }

  async listOrderMediaForApi(orderId: string, baseUrl: string): Promise<
    Array<{
      id: string;
      file_path: string;
      url: string;
      created_at: string;
      media_type: string;
      size_bytes: number;
      width: number | null;
      height: number | null;
    }>
  > {
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

  /** Удалить файлы и строки media_assets для заказов организации (перед удалением заказов). */
  async purgeMediaForOrders(orderIds: string[]): Promise<{ deleted_assets: number }> {
    if (orderIds.length === 0) return { deleted_assets: 0 };
    const links = await this.orderMediaRepo.find({
      where: { orderId: In(orderIds) },
      relations: ['mediaAsset'],
    });
    const seen = new Set<string>();
    for (const l of links) {
      const a = l.mediaAsset;
      if (!a || seen.has(a.id)) continue;
      seen.add(a.id);
      await this.storage.deleteObject(a.storageKey);
    }
    const assetIds = [...seen];
    if (assetIds.length === 0) return { deleted_assets: 0 };
    const result = await this.assetRepo.delete({ id: In(assetIds) });
    return { deleted_assets: result.affected ?? 0 };
  }

  /**
   * Изображения к сообщению чата (сжатие как у заказа). organizationId — из чата или null (поддержка).
   */
  async addImagesToChatMessage(params: {
    messageId: string;
    chatId: string;
    organizationId: string | null;
    files: Express.Multer.File[];
    uploadedByUserId?: string | null;
  }): Promise<void> {
    const { messageId, chatId, organizationId, files, uploadedByUserId } = params;
    let sortOrder = 0;
    for (const file of files) {
      const raw = file.buffer?.length ? file.buffer : null;
      if (!raw || raw.length === 0) {
        throw new BadRequestException('Пустой файл');
      }
      if (raw.length > MAX_ORDER_IMAGE_UPLOAD_BYTES) {
        throw new BadRequestException('Файл слишком большой (максимум 25 МБ до сжатия).');
      }
      const mime = resolveOrderUploadMime(file.mimetype, file.originalname, raw);
      if (!ALLOWED_ORDER_IMAGE_MIMES.has(mime)) {
        throw new BadRequestException('Допустимы только изображения JPEG, PNG, WebP, HEIC.');
      }
      let processed;
      try {
        processed = await processOrderImageUpload(raw);
      } catch {
        throw new BadRequestException('Не удалось обработать изображение. Загрузите другой файл.');
      }
      const prefix =
        organizationId != null && organizationId !== ''
          ? `${organizationId}/chats/${chatId}`
          : `support/chats/${chatId}`;
      const storageKey = `${prefix}/${randomUUID()}.webp`;
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

  async getLocalPathForChatAttachment(chatId: string, assetId: string): Promise<string | null> {
    const asset = await this.assetRepo.findOne({ where: { id: assetId, chatId } });
    if (!asset || asset.storageProvider !== 'local') return null;
    return this.storage.getAbsolutePath(asset.storageKey);
  }

  async getChatAttachmentDtosByMessageIds(
    chatId: string,
    messageIds: string[],
    baseUrl: string,
  ): Promise<
    Map<
      string,
      Array<{
        id: string;
        url: string;
        mime_type: string;
        width: number | null;
        height: number | null;
        size_bytes: number;
      }>
    >
  > {
    const map = new Map<
      string,
      Array<{
        id: string;
        url: string;
        mime_type: string;
        width: number | null;
        height: number | null;
        size_bytes: number;
      }>
    >();
    if (messageIds.length === 0) return map;
    const rows = await this.chatMsgAttRepo.find({
      where: { messageId: In(messageIds) },
      relations: ['mediaAsset'],
      order: { sortOrder: 'ASC' },
    });
    for (const r of rows) {
      const a = r.mediaAsset;
      if (!a || a.chatId !== chatId) continue;
      const dto = {
        id: a.id,
        url: `${baseUrl}/chats/${chatId}/attachments/${a.id}/file`,
        mime_type: a.mimeType,
        width: a.width,
        height: a.height,
        size_bytes: a.sizeBytes,
      };
      if (!map.has(r.messageId)) map.set(r.messageId, []);
      map.get(r.messageId)!.push(dto);
    }
    return map;
  }
}
