import { CarBrand } from './car-brand.entity';
export declare class CarModel {
    id: number;
    brandId: number;
    name: string;
    sortOrder: number;
    brand: CarBrand;
}
