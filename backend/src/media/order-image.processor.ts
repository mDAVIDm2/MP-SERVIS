import sharp from 'sharp';

const MAX_DIMENSION = 1920;
const WEBP_QUALITY = 78;

export interface ProcessedOrderImage {
  buffer: Buffer;
  width: number;
  height: number;
  mimeType: string;
}

export async function processOrderImageUpload(input: Buffer): Promise<ProcessedOrderImage> {
  const img = sharp(input).rotate();
  const meta = await img.metadata();
  const resized = img.resize({
    width: MAX_DIMENSION,
    height: MAX_DIMENSION,
    fit: 'inside',
    withoutEnlargement: true,
  });
  const buffer = await resized.webp({ quality: WEBP_QUALITY }).toBuffer();
  const outMeta = await sharp(buffer).metadata();
  return {
    buffer,
    width: outMeta.width ?? meta.width ?? 0,
    height: outMeta.height ?? meta.height ?? 0,
    mimeType: 'image/webp',
  };
}

export const ALLOWED_ORDER_IMAGE_MIMES = new Set([
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
]);

export const MAX_ORDER_IMAGE_UPLOAD_BYTES = 25 * 1024 * 1024;
