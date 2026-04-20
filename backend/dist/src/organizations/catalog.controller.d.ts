import { ServiceCatalogService } from '../reference/service-catalog.service';
import { OrganizationsService } from './organizations.service';
type ServicePayloadRow = {
    id: string;
    name: string;
    price_kopecks: number;
    duration_minutes: number;
    catalog_item_id?: string;
    use_body_type_pricing?: boolean;
    body_type_pricing?: Array<{
        body_type?: string;
        price_kopecks?: number;
        duration_minutes?: number;
    }>;
};
export declare class CatalogController {
    private org;
    private serviceCatalog;
    constructor(org: OrganizationsService, serviceCatalog: ServiceCatalogService);
    getCatalogServices(businessKind?: string): Promise<{
        categories: {
            category_key: string;
            category_name: string;
            category_sort_order: number;
            items: unknown[];
        }[];
    }>;
    search(q?: string, businessKind?: string): Promise<{
        items: {
            id: string;
            name: string;
            address: string;
            phone: string;
            working_hours: string;
            car_brands: string[];
            latitude?: number;
            longitude?: number;
            photo_urls: string[];
            service_ids: string[];
            services: ServicePayloadRow[];
            business_kind: string;
            business_kind_label: string;
            scheduling_mode: string;
        }[];
    }>;
    getOrganization(id: string): Promise<{
        id: string;
        name: string;
        address: string;
        phone: string;
        working_hours: string;
        timezone: any;
        car_brands: string[];
        latitude: any;
        longitude: any;
        photo_urls: string[];
        business_kind: string;
        business_kind_label: string;
        scheduling_mode: string;
    }>;
    getOrganizationServices(id: string): Promise<{
        categories: {
            id: string;
            name: string;
            order?: number;
        }[];
        items: {
            catalog_item_id?: string | undefined;
            id: string;
            category_id: string;
            name: string;
            price_kopecks: number;
            duration_minutes: number;
            required_skill: any;
            use_body_type_pricing: boolean;
            body_type_pricing: {
                body_type?: string;
                price_kopecks?: number;
                duration_minutes?: number;
            }[];
        }[];
        packages: {
            id: string;
            name: string;
            category_id: string;
            package_price_kopecks: number;
            package_duration_minutes: number;
            included_service_ids: string[];
            addons: {
                service_id: string | undefined;
                extra_price_kopecks: number;
                extra_duration_minutes: number;
            }[];
        }[];
    }>;
}
export {};
