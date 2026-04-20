import { OnModuleInit } from '@nestjs/common';
import { Repository } from 'typeorm';
import { ServiceCatalogItem } from './service-catalog-item.entity';
import { ServiceCatalogSuggestion } from './service-catalog-suggestion.entity';
import { Organization } from '../organizations/organization.entity';
export { catalogAllowedKindsForCategoryKey } from './service-catalog-metadata';
export declare class ServiceCatalogService implements OnModuleInit {
    private itemRepo;
    private suggestRepo;
    private orgRepo;
    constructor(itemRepo: Repository<ServiceCatalogItem>, suggestRepo: Repository<ServiceCatalogSuggestion>, orgRepo: Repository<Organization>);
    onModuleInit(): Promise<void>;
    seedIfEmpty(): Promise<void>;
    private filterCatalogItemsByBusinessKind;
    getCatalogGrouped(organizationId?: string | null, businessKindFilter?: string | null): Promise<{
        categories: {
            category_key: string;
            category_name: string;
            category_sort_order: number;
            items: unknown[];
        }[];
    }>;
    resolveItemBasicsByIds(ids: string[]): Promise<Map<string, {
        name: string;
        defaultDurationMinutes: number;
    }>>;
    private nextCategorySortOrder;
    private nextItemSortOrder;
    createCatalogCategoryAdmin(dto: {
        category_key: string;
        category_name: string;
        first_service_name?: string;
    }): Promise<{
        categories: {
            category_key: string;
            category_name: string;
            category_sort_order: number;
            items: unknown[];
        }[];
    }>;
    createCatalogItemAdmin(dto: {
        id?: string;
        category_key: string;
        category_name: string;
        name: string;
        default_duration_minutes?: number;
        sort_order?: number;
        required_skill?: string | null;
    }): Promise<{
        categories: {
            category_key: string;
            category_name: string;
            category_sort_order: number;
            items: unknown[];
        }[];
    }>;
    updateCatalogItemAdmin(id: string, dto: {
        name?: string;
        default_duration_minutes?: number;
        required_skill?: string | null;
        sort_order?: number;
        category_key?: string;
        category_name?: string;
    }): Promise<{
        categories: {
            category_key: string;
            category_name: string;
            category_sort_order: number;
            items: unknown[];
        }[];
    }>;
    deleteCatalogItemAdmin(id: string): Promise<{
        categories: {
            category_key: string;
            category_name: string;
            category_sort_order: number;
            items: unknown[];
        }[];
    }>;
    deleteCatalogCategoryAdmin(categoryKeyRaw: string): Promise<{
        categories: {
            category_key: string;
            category_name: string;
            category_sort_order: number;
            items: unknown[];
        }[];
    }>;
    patchCatalogCategoryAdmin(categoryKeyRaw: string, dto: {
        category_name?: string;
        new_category_key?: string;
    }): Promise<{
        categories: {
            category_key: string;
            category_name: string;
            category_sort_order: number;
            items: unknown[];
        }[];
    }>;
    reorderCatalogCategoryAdmin(categoryKeyRaw: string, delta: number): Promise<{
        categories: {
            category_key: string;
            category_name: string;
            category_sort_order: number;
            items: unknown[];
        }[];
    }>;
    reorderCatalogItemAdmin(itemId: string, delta: number): Promise<{
        categories: {
            category_key: string;
            category_name: string;
            category_sort_order: number;
            items: unknown[];
        }[];
    }>;
    createSuggestion(organizationId: string, dto: {
        requested_name: string;
        category_hint?: string;
        note?: string;
    }): Promise<{
        id: string;
        status: string;
        message: string;
    }>;
    getSuggestionStats(): Promise<{
        pending: number;
        reviewed: number;
        total: number;
    }>;
    listSuggestionsAdmin(params: {
        status?: string;
        page?: number;
        limit?: number;
        q?: string;
    }): Promise<{
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
    updateSuggestionAdmin(id: string, dto: {
        status: string;
        review_note?: string | null;
    }): Promise<{
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
