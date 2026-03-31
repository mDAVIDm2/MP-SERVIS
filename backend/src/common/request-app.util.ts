import { Request } from 'express';

/** Клиентское приложение (записи как клиент даже при наличии organization_id у пользователя). */
export function isClientAppRequest(req: Request): boolean {
  const raw = req.headers['x-autohub-app'] ?? (req.headers as Record<string, unknown>)['X-AutoHub-App'];
  return String(raw ?? '').toLowerCase() === 'client';
}
