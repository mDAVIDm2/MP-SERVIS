/** Проверка обязательных секретов до поднятия Nest (production). */
export function assertProductionSecrets(): void {
  if (process.env.NODE_ENV !== 'production') return;
  if (!process.env.JWT_SECRET?.trim()) {
    throw new Error('JWT_SECRET is required when NODE_ENV=production');
  }
  if (!process.env.INTERNAL_JWT_SECRET?.trim()) {
    throw new Error('INTERNAL_JWT_SECRET is required when NODE_ENV=production');
  }
}
