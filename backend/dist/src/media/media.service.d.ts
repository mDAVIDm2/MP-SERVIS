import { Repository } from 'typeorm';
import { MediaAsset } from './media-asset.entity';
import { OrderMedia } from './order-media.entity';
import { ChatMessageAttachment } from '../chats/chat-message-attachment.entity';
import { LocalStorageService } from './local-storage.service';
export declare class MediaService {
    private readonly assetRepo;
    private readonly orderMediaRepo;
    private readonly chatMsgAttRepo;
    private readonly storage;
    constructor(assetRepo: Repository<MediaAsset>, orderMediaRepo: Repository<OrderMedia>, chatMsgAttRepo: Repository<ChatMessageAttachment>, storage: LocalStorageService);
    countOrderMediaLinks(orderId: string): Promise<number>;
    attachOrderImage(params: {
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
    }>;
    getLocalFilePathForOrderPhoto(orderId: string, photoId: string): Promise<string | null>;
    listOrderMediaForApi(orderId: string, baseUrl: string): Promise<Array<{
        id: string;
        file_path: string;
        url: string;
        created_at: string;
        media_type: string;
        size_bytes: number;
        width: number | null;
        height: number | null;
    }>>;
    purgeMediaForOrders(orderIds: string[]): Promise<{
        deleted_assets: number;
    }>;
    addImagesToChatMessage(params: {
        messageId: string;
        chatId: string;
        organizationId: string | null;
        files: Express.Multer.File[];
        uploadedByUserId?: string | null;
    }): Promise<void>;
    getLocalPathForChatAttachment(chatId: string, assetId: string): Promise<string | null>;
    getChatAttachmentDtosByMessageIds(chatId: string, messageIds: string[], baseUrl: string): Promise<Map<string, Array<{
        id: string;
        url: string;
        mime_type: string;
        width: number | null;
        height: number | null;
        size_bytes: number;
    }>>>;
}
