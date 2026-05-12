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
  /** HEIC/HEIF: sharp обрабатывает при наличии libheif в окружении; иначе — исключение при обработке. */
  'image/heic',
  'image/heif',
]);

export const MAX_ORDER_IMAGE_UPLOAD_BYTES = 25 * 1024 * 1024;

function inferMimeFromFilename(originalname: string | undefined | null): string | null {
  const n = String(originalname ?? '').toLowerCase();
  if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.webp')) return 'image/webp';
  if (n.endsWith('.heic')) return 'image/heic';
  if (n.endsWith('.heif')) return 'image/heif';
  return null;
}

/** Сигнатура по magic bytes, если multer дал application/octet-stream (часто с Flutter/Dio). */
function sniffImageMimeFromBuffer(buf: Buffer): string | null {
  if (buf.length < 12) return null;
  if (buf[0] === 0xff && buf[1] === 0xd8) return 'image/jpeg';
  if (buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47) return 'image/png';
  if (buf[0] === 0x52 && buf[1] === 0x49 && buf[2] === 0x46 && buf[3] === 0x46) return 'image/webp';
  if (buf.length >= 12) {
    const t = buf.slice(4, 8).toString('ascii');
    if (t === 'ftyp') {
      const brand = buf.slice(8, 12).toString('ascii').toLowerCase();
      if (brand.includes('heic') || brand.includes('mif1') || brand.includes('msf1')) {
        return 'image/heic';
      }
    }
  }
  return null;
}

/**
 * Multer часто не получает Content-Type для части multipart (моб. клиенты) → application/octet-stream.
 * Восстанавливаем по объявленному mimetype, имени файла и сигнатуре буфера.
 */
export function resolveOrderUploadMime(
  multerMime: string | undefined,
  originalname: string | undefined | null,
  buffer: Buffer,
): string {
  const m = String(multerMime || '')
    .toLowerCase()
    .split(';')[0]
    .trim();
  if (m === 'image/jpg') {
    return 'image/jpeg';
  }
  if (ALLOWED_ORDER_IMAGE_MIMES.has(m)) {
    return m;
  }
  const loose = ['application/octet-stream', 'binary/octet-stream', '', 'application/x-www-form-urlencoded'];
  if (loose.includes(m)) {
    const fromName = inferMimeFromFilename(originalname);
    if (fromName && ALLOWED_ORDER_IMAGE_MIMES.has(fromName)) {
      return fromName;
    }
    const sniffed = sniffImageMimeFromBuffer(buffer);
    if (sniffed && ALLOWED_ORDER_IMAGE_MIMES.has(sniffed)) {
      return sniffed;
    }
  }
  return m;
}
