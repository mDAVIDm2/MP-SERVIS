import { Request } from 'express';

/** Клиентское приложение (записи как клиент даже при наличии organization_id у пользователя). */
export function isClientAppRequest(req: Request): boolean {
  const raw = req.headers['x-mp-servis-app'] ?? (req.headers as Record<string, unknown>)['X-MP-Servis-App'];
  return String(raw ?? '').toLowerCase() === 'client';
}
