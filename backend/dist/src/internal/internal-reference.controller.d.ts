import { InternalOperator } from './internal-operator.entity';
import { InternalAuditService } from './internal-audit.service';
import { ReferenceService } from '../reference/reference.service';
import { ServiceCatalogService } from '../reference/service-catalog.service';
export declare class InternalReferenceController {
    private readonly reference;
    private readonly serviceCatalog;
    private readonly audit;
    constructor(reference: ReferenceService, serviceCatalog: ServiceCatalogService, audit: InternalAuditService);
    getServiceCatalog(): Promise<{
        categories: {
            category_key: string;
            category_name: string;
            category_sort_order: number;
            items: unknown[];
        }[];
    }>;
    createServiceCatalogCategory(body: {
        category_key: string;
        category_name: string;
        first_service_name?: string;
    }, operator: InternalOperator): Promise<{
        categories: {
            category_key: string;
            category_name: string;
            category_sort_order: number;
            items: unknown[];
        }[];
    }>;
    patchServiceCatalogCategory(body: {
        category_key: string;
        category_name?: string;
        new_category_key?: string;
    }, operator: InternalOperator): Promise<{
        categories: {
            category_key: string;
            category_name: string;
            category_sort_order: number;
            items: unknown[];
        }[];
    }>;
    deleteServiceCatalogCategory(categoryKey: string, operator: InternalOperator): Promise<{
        categories: {
            category_key: string;
            category_name: string;
            category_sort_order: number;
            items: unknown[];
        }[];
    }>;
    reorderServiceCatalogCategory(body: {
        category_key: string;
        delta: number;
    }, operator: InternalOperator): Promise<{
        categories: {
            category_key: string;
            category_name: string;
            category_sort_order: number;
            items: unknown[];
        }[];
    }>;
    createServiceCatalogItem(body: {
        id?: string;
        category_key: string;
        category_name: string;
        name: string;
        default_duration_minutes?: number;
        sort_order?: number;
        required_skill?: string | null;
    }, operator: InternalOperator): Promise<{
        categories: {
            category_key: string;
            category_name: string;
            category_sort_order: number;
            items: unknown[];
        }[];
    }>;
    patchServiceCatalogItem(id: string, body: {
        name?: string;
        default_duration_minutes?: number;
        required_skill?: string | null;
        sort_order?: number;
        category_key?: string;
    }, operator: InternalOperator): Promise<{
        categories: {
            category_key: string;
            category_name: string;
            category_sort_order: number;
            items: unknown[];
        }[];
    }>;
    deleteServiceCatalogItem(id: string, operator: InternalOperator): Promise<{
        categories: {
            category_key: string;
            category_name: string;
            category_sort_order: number;
            items: unknown[];
        }[];
    }>;
    reorderServiceCatalogItem(id: string, body: {
        delta: number;
    }, operator: InternalOperator): Promise<{
        categories: {
            category_key: string;
            category_name: string;
            category_sort_order: number;
            items: unknown[];
        }[];
    }>;
    getCarBrands(): Promise<import("../reference/reference.service").CarBrandDto[]>;
    createBrand(body: {
        name: string;
    }): Promise<import("../reference/reference.service").CarBrandDto>;
    deleteBrand(id: number): Promise<{
        ok: boolean;
    }>;
    getCarModels(brandId: number): Promise<import("../reference/reference.service").CarModelDto[]>;
    createModel(brandId: number, body: {
        name: string;
    }): Promise<import("../reference/reference.service").CarModelDto>;
    deleteModel(id: number): Promise<{
        ok: boolean;
    }>;
    getCarGenerations(modelId: number): Promise<import("../reference/reference.service").CarGenerationDto[]>;
    createGeneration(modelId: number, body: {
        name: string;
        year_from?: number;
        year_to?: number;
    }): Promise<import("../reference/reference.service").CarGenerationDto>;
    deleteGeneration(id: number): Promise<{
        ok: boolean;
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
        carSnapshotBrand: string | null;
        carSnapshotModel: string | null;
        carBrandId: number | null;
        carModelId: number | null;
    }[]>;
    approvePending(id: string): Promise<{
        brandId?: number;
        modelId?: number;
        generationId?: number;
    }>;
    rejectPending(id: string): Promise<{
        ok: boolean;
    }>;
    suggestPending(id: string, body: {
        brandId: number;
        modelId: number;
        generationId: number;
    }): Promise<{
        ok: boolean;
    }>;
}
