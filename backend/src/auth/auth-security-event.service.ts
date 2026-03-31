import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { SecurityEvent } from './security-event.entity';
import { NotificationsService } from '../notifications/notifications.service';

const CRITICAL_TYPES = new Set([
  'refresh_reuse_detected',
  'sessions_revoked_all_except',
  'session_revoked',
  'login_failed',
]);

@Injectable()
export class AuthSecurityEventService {
  constructor(
    @InjectRepository(SecurityEvent) private readonly repo: Repository<SecurityEvent>,
    private readonly notifications: NotificationsService,
  ) {}

  async record(
    userId: string,
    type: string,
    opts: { sessionId?: string | null; ip?: string | null; userAgent?: string | null; metadata?: Record<string, unknown> },
  ): Promise<void> {
    const row = this.repo.create({
      userId,
      type,
      sessionId: opts.sessionId ?? null,
      ip: opts.ip ?? null,
      userAgent: opts.userAgent ?? null,
      metadata: opts.metadata ?? null,
    });
    await this.repo.save(row);

    if (CRITICAL_TYPES.has(type)) {
      const titles: Record<string, string> = {
        refresh_reuse_detected: 'Безопасность: попытка повторного использования сессии',
        sessions_revoked_all_except: 'Завершены другие сессии',
        session_revoked: 'Сессия завершена',
        login_failed: 'Неудачная попытка входа',
      };
      await this.notifications.create({
        userId,
        type: 'security',
        title: titles[type] || 'Событие безопасности',
        body: type,
        payload: { security_event_type: type, ...opts.metadata },
      });
    }
  }

  async listForUser(userId: string, limit = 50) {
    const rows = await this.repo.find({
      where: { userId },
      order: { createdAt: 'DESC' },
      take: limit,
    });
    return rows.map((r) => ({
      id: r.id,
      type: r.type,
      metadata: r.metadata,
      session_id: r.sessionId,
      created_at: r.createdAt instanceof Date ? r.createdAt.toISOString() : r.createdAt,
    }));
  }
}
