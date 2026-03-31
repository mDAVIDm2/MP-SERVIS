import { ChatMessage } from './chat-message.entity';
import { MediaAsset } from '../media/media-asset.entity';
export declare class ChatMessageAttachment {
    id: string;
    messageId: string;
    message: ChatMessage;
    mediaAssetId: string;
    mediaAsset: MediaAsset;
    sortOrder: number;
    createdAt: Date;
}
