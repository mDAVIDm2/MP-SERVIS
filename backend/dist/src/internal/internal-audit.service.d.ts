import { Repository } from 'typeorm';
import { AuditLog } from '../audit/audit-log.entity';
import { InternalOperator } from './internal-operator.entity';
export declare class InternalAuditService {
    private readonly repo;
    constructor(repo: Repository<AuditLog>);
    logInternal(operator: InternalOperator, action: string, resourceType: string | null, resourceId: string | null, details: Record<string, unknown> | null): Promise<void>;
    find(limit?: number, offset?: number, from?: string, to?: string): Promise<{
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
