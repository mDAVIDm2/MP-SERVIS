import { CarModel } from './car-model.entity';
export declare class CarGeneration {
    id: number;
    modelId: number;
    name: string;
    yearFrom: number | null;
    yearTo: number | null;
    sortOrder: number;
    model: CarModel;
}
