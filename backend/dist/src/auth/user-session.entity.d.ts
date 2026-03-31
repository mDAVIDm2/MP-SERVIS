export declare class UserSession {
    id: string;
    familyId: string;
    userId: string;
    refreshHash: string;
    deviceId: string | null;
    deviceName: string | null;
    platform: string | null;
    userAgent: string | null;
    ip: string | null;
    createdAt: Date;
    lastSeenAt: Date | null;
    revokedAt: Date | null;
    replacedBySessionId: string | null;
    jwtAudience: string;
}
