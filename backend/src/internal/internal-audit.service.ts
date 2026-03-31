import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuditLog } from '../audit/audit-log.entity';
import { InternalOperator } from './internal-operator.entity';

@Injectable()
export class InternalAuditService {
  constructor(
    @InjectRepository(AuditLog)
    private readonly repo: Repository<AuditLog>,
  ) {}

  async logInternal(
    operator: InternalOperator,
    action: string,
    resourceType: string | null,
    resourceId: string | null,
    details: Record<string, unknown> | null,
  ) {
    const actorName = operator.name || operator.email;
    await this.repo
      .save(
        this.repo.create({
          actorId: operator.id,
          actorType: 'internal',
          actorName,
          action,
          resourceType,
          resourceId,
          details,
        }),
      )
      .catch(() => {});
  }

  async find(limit = 100, offset = 0, from?: string, to?: string) {
    const qb = this.repo
      .createQueryBuilder('a')
      .orderBy('a.createdAt', 'DESC')
      .take(limit)
      .skip(offset);

    if (from) {
      qb.andWhere('a.createdAt >= :from', { from: new Date(from) });
    }
    if (to) {
      qb.andWhere('a.createdAt <= :to', { to: new Date(to) });
    }

    const [items, total] = await qb.getManyAndCount();
    return {
      items: items.map((a) => ({
        id: a.id,
        actor_id: a.actorId,
        actor_type: a.actorType,
        actor_name: a.actorName,
        action: a.action,
        resource_type: a.resourceType,
        resource_id: a.resourceId,
        details: a.details,
        created_at: a.createdAt?.toISOString?.(),
      })),
      total,
    };
  }
}
