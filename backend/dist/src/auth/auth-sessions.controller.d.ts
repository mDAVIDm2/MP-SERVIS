import { JwtService } from '@nestjs/jwt';
import { Request } from 'express';
import { User } from '../users/user.entity';
import { AuthSessionService } from './auth-session.service';
import { AuthSecurityEventService } from './auth-security-event.service';
export declare class AuthSessionsController {
    private readonly sessions;
    private readonly securityEvents;
    private readonly jwt;
    constructor(sessions: AuthSessionService, securityEvents: AuthSecurityEventService, jwt: JwtService);
    private currentSessionId;
    listSessions(req: Request & {
        user: User;
    }): Promise<{
        items: {
            id: string;
            created_at: string;
            last_seen_at: string | null;
            device_name: string | null;
            platform: string | null;
            revoked: boolean;
            is_current: boolean;
        }[];
    }>;
    listSecurityEvents(req: Request & {
        user: User;
    }): Promise<{
        items: {
            id: string;
            type: string;
            metadata: Record<string, unknown> | null;
            session_id: string | null;
            created_at: string;
        }[];
    }>;
    revokeSession(req: Request & {
        user: User;
    }, id: string): Promise<{
        ok: boolean;
    }>;
    revokeOthers(req: Request & {
        user: User;
    }): Promise<{
        ok: boolean;
        revoked: number;
    }>;
}
