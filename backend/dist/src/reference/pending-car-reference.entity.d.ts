export declare class PendingCarReference {
    id: string;
    userId: string;
    carId: string;
    pendingBrand: string | null;
    pendingModel: string | null;
    pendingGeneration: string | null;
    status: 'pending' | 'approved' | 'rejected' | 'suggested';
    createdAt: Date;
}
