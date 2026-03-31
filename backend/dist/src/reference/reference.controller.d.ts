import { ReferenceService } from './reference.service';
import { ServiceCatalogService } from './service-catalog.service';
export declare class ReferenceController {
    private readonly reference;
    private readonly serviceCatalog;
    constructor(reference: ReferenceService, serviceCatalog: ServiceCatalogService);
    getCarBrands(): Promise<import("./reference.service").CarBrandDto[]>;
    getCarModels(brandId: number): Promise<import("./reference.service").CarModelDto[]>;
    getCarGenerations(modelId: number): Promise<import("./reference.service").CarGenerationDto[]>;
    createPending(req: {
        user: {
            id: string;
        };
    }, body: Record<string, unknown>): Promise<{
        id: string;
    }>;
    listPending(): Promise<{
        id: string;
        userId: string;
        carId: string;
        pendingBrand: string | null;
        pendingModel: string | null;
        pendingGeneration: string | null;
        status: string;
        createdAt: Date;
    }[]>;
    getServiceCatalog(organizationId?: string, businessKind?: string, req?: {
        user?: {
            organizationId?: string | null;
        };
    }): Promise<{
        categories: {
            category_key: string;
            category_name: string;
            category_sort_order: number;
            items: unknown[];
        }[];
    }>;
    suggestServiceCatalog(req: {
        user: {
            organizationId: string | null;
        };
    }, body: {
        requested_name?: string;
        category_hint?: string;
        note?: string;
    }): Promise<{
        id: string;
        status: string;
        message: string;
    }>;
}
