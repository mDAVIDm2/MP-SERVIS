import { InternalOperator } from './internal-operator.entity';
import { ServiceCatalogService } from '../reference/service-catalog.service';
import { PatchServiceCatalogSuggestionDto } from './dto/patch-service-catalog-suggestion.dto';
import { InternalAuditService } from './internal-audit.service';
export declare class InternalServiceCatalogSuggestionsController {
    private readonly catalog;
    private readonly audit;
    constructor(catalog: ServiceCatalogService, audit: InternalAuditService);
    stats(): Promise<{
        pending: number;
        reviewed: number;
        total: number;
    }>;
    list(status?: string, q?: string, pageStr?: string, limitStr?: string): Promise<{
        items: {
            id: string;
            organization_id: string;
            organization_name: string;
            requested_name: string;
            category_hint: string | null;
            note: string | null;
            status: string;
            created_at: string;
            reviewed_at: string | null;
            review_note: string | null;
        }[];
        total: number;
        page: number;
        limit: number;
        pages: number;
    }>;
    patch(id: string, body: PatchServiceCatalogSuggestionDto, operator: InternalOperator): Promise<{
        id: string;
        organization_id: string;
        organization_name: string;
        requested_name: string;
        category_hint: string | null;
        note: string | null;
        status: string;
        created_at: string;
        reviewed_at: string | null;
        review_note: string | null;
    }>;
}
