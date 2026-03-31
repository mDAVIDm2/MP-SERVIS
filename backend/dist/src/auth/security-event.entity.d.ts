export declare class SecurityEvent {
    id: string;
    userId: string;
    type: string;
    metadata: Record<string, unknown> | null;
    sessionId: string | null;
    ip: string | null;
    userAgent: string | null;
    createdAt: Date;
}
