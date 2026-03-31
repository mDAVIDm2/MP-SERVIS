import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Repository } from 'typeorm';
import { User } from '../users/user.entity';
import { UserSession } from './user-session.entity';
import { AuthSecurityEventService } from './auth-security-event.service';
export type JwtAudience = 'client' | 'business';
export interface SessionDeviceMeta {
    deviceId?: string | null;
    deviceName?: string | null;
    platform?: string | null;
    userAgent?: string | null;
    ip?: string | null;
}
export interface TokenPair {
    access_token: string;
    refresh_token: string;
    session_id: string;
    expires_in: number;
}
export interface RefreshResult extends TokenPair {
    userId: string;
}
export declare class AuthSessionService {
    private readonly repo;
    private readonly jwt;
    private readonly config;
    private readonly securityEvents;
    private readonly refreshBcryptRounds;
    constructor(repo: Repository<UserSession>, jwt: JwtService, config: ConfigService, securityEvents: AuthSecurityEventService);
    private pepper;
    private hashKey;
    parseRefreshToken(refreshToken: string): {
        sessionId: string;
        secret: string;
    } | null;
    private accessExpiresIn;
    private accessExpiresInSeconds;
    createSession(user: User, audience: JwtAudience, meta: SessionDeviceMeta): Promise<TokenPair>;
    refreshTokens(refreshToken: string, audience: JwtAudience, meta: SessionDeviceMeta): Promise<RefreshResult>;
    revokeByRefreshToken(refreshToken: string): Promise<{
        userId: string;
    } | null>;
    revokeSession(userId: string, sessionId: string): Promise<boolean>;
    revokeAllForUser(userId: string): Promise<number>;
    revokeAllExcept(userId: string, exceptSessionId: string): Promise<number>;
    private revokeFamily;
    assertSessionActive(sessionId: string, userId: string): Promise<UserSession | null>;
    listSessions(userId: string, currentSessionId: string | null): Promise<{
        id: string;
        created_at: string;
        last_seen_at: string | null;
        device_name: string | null;
        platform: string | null;
        revoked: boolean;
        is_current: boolean;
    }[]>;
    touchSession(sessionId: string, userId: string): Promise<void>;
}
