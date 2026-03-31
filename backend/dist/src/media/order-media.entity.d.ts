import { Order } from '../orders/order.entity';
import { MediaAsset } from './media-asset.entity';
export declare class OrderMedia {
    id: string;
    orderId: string;
    order: Order;
    mediaAssetId: string;
    mediaAsset: MediaAsset;
    sortOrder: number;
    createdAt: Date;
}
