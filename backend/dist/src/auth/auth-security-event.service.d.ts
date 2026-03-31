import { Repository } from 'typeorm';
import { SecurityEvent } from './security-event.entity';
import { NotificationsService } from '../notifications/notifications.service';
export declare class AuthSecurityEventService {
    private readonly repo;
    private readonly notifications;
    constructor(repo: Repository<SecurityEvent>, notifications: NotificationsService);
    record(userId: string, type: string, opts: {
        sessionId?: string | null;
        ip?: string | null;
        userAgent?: string | null;
        metadata?: Record<string, unknown>;
    }): Promise<void>;
    listForUser(userId: string, limit?: number): Promise<{
        id: string;
        type: string;
        metadata: Record<string, unknown> | null;
        session_id: string | null;
        created_at: string;
    }[]>;
}
