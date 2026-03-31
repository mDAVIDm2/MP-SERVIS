"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.MAX_ORDER_IMAGE_UPLOAD_BYTES = exports.ALLOWED_ORDER_IMAGE_MIMES = void 0;
exports.processOrderImageUpload = processOrderImageUpload;
const sharp_1 = require("sharp");
const MAX_DIMENSION = 1920;
const WEBP_QUALITY = 78;
async function processOrderImageUpload(input) {
    const img = (0, sharp_1.default)(input).rotate();
    const meta = await img.metadata();
    const resized = img.resize({
        width: MAX_DIMENSION,
        height: MAX_DIMENSION,
        fit: 'inside',
        withoutEnlargement: true,
    });
    const buffer = await resized.webp({ quality: WEBP_QUALITY }).toBuffer();
    const outMeta = await (0, sharp_1.default)(buffer).metadata();
    return {
        buffer,
        width: outMeta.width ?? meta.width ?? 0,
        height: outMeta.height ?? meta.height ?? 0,
        mimeType: 'image/webp',
    };
}
exports.ALLOWED_ORDER_IMAGE_MIMES = new Set([
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
]);
exports.MAX_ORDER_IMAGE_UPLOAD_BYTES = 25 * 1024 * 1024;
//# sourceMappingURL=order-image.processor.js.map