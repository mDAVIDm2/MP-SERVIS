import { Repository } from 'typeorm';
import { CarBrand } from './car-brand.entity';
import { CarModel } from './car-model.entity';
import { CarGeneration } from './car-generation.entity';
import { PendingCarReference } from './pending-car-reference.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { ClientCar } from '../users/client-car.entity';
export interface CarBrandDto {
    id: number;
    name: string;
}
export interface CarModelDto {
    id: number;
    name: string;
}
export interface CarGenerationDto {
    id: number;
    name: string;
    yearFrom?: number | null;
    yearTo?: number | null;
}
export declare class ReferenceService {
    private brandRepo;
    private modelRepo;
    private generationRepo;
    private pendingRepo;
    private clientCarRepo;
    private notifications;
    constructor(brandRepo: Repository<CarBrand>, modelRepo: Repository<CarModel>, generationRepo: Repository<CarGeneration>, pendingRepo: Repository<PendingCarReference>, clientCarRepo: Repository<ClientCar>, notifications: NotificationsService);
    getCarBrands(): Promise<CarBrandDto[]>;
    getCarModels(brandId: number): Promise<CarModelDto[]>;
    getCarGenerations(modelId: number): Promise<CarGenerationDto[]>;
    createPending(userId: string, carId: string, data: {
        pendingBrand?: string;
        pendingModel?: string;
        pendingGeneration?: string;
        referenceBrandId?: number;
        referenceModelId?: number;
    }): Promise<{
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
        carSnapshotBrand: string | null;
        carSnapshotModel: string | null;
        carBrandId: number | null;
        carModelId: number | null;
    }[]>;
    createBrand(name: string): Promise<CarBrandDto>;
    createModel(brandId: number, name: string): Promise<CarModelDto>;
    createGeneration(modelId: number, name: string, yearFrom?: number | null, yearTo?: number | null): Promise<CarGenerationDto>;
    approvePending(id: string): Promise<{
        brandId?: number;
        modelId?: number;
        generationId?: number;
    }>;
    rejectPending(id: string): Promise<void>;
    suggestPending(id: string, data: {
        brandId: number;
        modelId: number;
        generationId: number;
    }): Promise<void>;
    deleteBrand(id: number): Promise<void>;
    deleteModel(id: number): Promise<void>;
    deleteGeneration(id: number): Promise<void>;
}
