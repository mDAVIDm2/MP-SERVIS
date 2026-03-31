export interface ProcessedOrderImage {
    buffer: Buffer;
    width: number;
    height: number;
    mimeType: string;
}
export declare function processOrderImageUpload(input: Buffer): Promise<ProcessedOrderImage>;
export declare const ALLOWED_ORDER_IMAGE_MIMES: Set<string>;
export declare const MAX_ORDER_IMAGE_UPLOAD_BYTES: number;
