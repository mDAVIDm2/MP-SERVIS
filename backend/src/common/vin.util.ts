import { BadRequestException } from '@nestjs/common';

/** VIN в БД до 32 символов: только заглавные латинские буквы и цифры, без пробелов. */
const VIN_BODY_RE = /^[A-Z0-9]+$/;
const VIN_MAX_LEN = 32;

/**
 * Нормализует необязательный VIN: trim, upper, без пробелов.
 * Пустая строка → null.
 * @throws BadRequestException если непустой и неверный формат
 */
export function normalizeOptionalVin(raw: unknown): string | null {
  if (raw == null) return null;
  const s = String(raw).trim().toUpperCase().replace(/\s/g, '');
  if (s.length === 0) return null;
  if (s.length > VIN_MAX_LEN) {
    throw new BadRequestException(`VIN не длиннее ${VIN_MAX_LEN} символов`);
  }
  if (!VIN_BODY_RE.test(s)) {
    throw new BadRequestException('VIN: только заглавные латинские буквы (A–Z) и цифры');
  }
  return s;
}
