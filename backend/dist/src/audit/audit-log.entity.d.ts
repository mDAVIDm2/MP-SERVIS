export type AuditActorType = 'internal' | 'system';
export declare class AuditLog {
    id: string;
    actorId: string | null;
    actorType: AuditActorType;
    actorName: string | null;
    action: string;
    resourceType: string | null;
    resourceId: string | null;
    details: Record<string, unknown> | null;
    createdAt: Date;
}
