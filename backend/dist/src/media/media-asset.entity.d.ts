import { Organization } from '../organizations/organization.entity';
import { User } from '../users/user.entity';
import { Chat } from '../chats/chat.entity';
export declare class MediaAsset {
    id: string;
    organizationId: string | null;
    organization: Organization | null;
    chatId: string | null;
    chat: Chat | null;
    uploadedByUserId: string | null;
    uploadedByUser: User | null;
    mediaType: string;
    mimeType: string;
    storageProvider: string;
    storageKey: string;
    originalFilename: string | null;
    sizeBytes: number;
    width: number | null;
    height: number | null;
    durationSec: number | null;
    status: string;
    createdAt: Date;
}
