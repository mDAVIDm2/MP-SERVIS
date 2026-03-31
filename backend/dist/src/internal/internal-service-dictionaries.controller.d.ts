import { ServiceCatalogService } from '../reference/service-catalog.service';
export declare class InternalServiceDictionariesController {
    private readonly serviceCatalog;
    constructor(serviceCatalog: ServiceCatalogService);
    list(): Promise<{
        categories: {
            category_key: string;
            category_name: string;
            category_sort_order: number;
            items: unknown[];
        }[];
        items: unknown[];
        total_items: number;
        total_categories: number;
    }>;
}
