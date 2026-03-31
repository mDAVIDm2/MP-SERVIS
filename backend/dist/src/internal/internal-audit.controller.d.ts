import { InternalAuditService } from './internal-audit.service';
export declare class InternalAuditController {
    private readonly audit;
    constructor(audit: InternalAuditService);
    list(limit?: string, offset?: string, from?: string, to?: string): Promise<{
        items: {
            id: string;
            actor_id: string | null;
            actor_type: import("../audit/audit-log.entity").AuditActorType;
            actor_name: string | null;
            action: string;
            resource_type: string | null;
            resource_id: string | null;
            details: Record<string, unknown> | null;
            created_at: string;
        }[];
        total: number;
    }>;
}
