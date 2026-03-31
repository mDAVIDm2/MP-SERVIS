import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { OrganizationInvitation } from './organization-invitation.entity';

@Injectable()
export class OrganizationInvitationsScheduler {
  private readonly log = new Logger(OrganizationInvitationsScheduler.name);

  constructor(
    @InjectRepository(OrganizationInvitation) private readonly invitationRepo: Repository<OrganizationInvitation>,
  ) {}

  @Cron(CronExpression.EVERY_HOUR)
  async expirePendingInvitations(): Promise<void> {
    const now = new Date();
    const res = await this.invitationRepo
      .createQueryBuilder()
      .update(OrganizationInvitation)
      .set({ status: 'expired', respondedAt: now })
      .where('status = :pending', { pending: 'pending' })
      .andWhere('expires_at IS NOT NULL')
      .andWhere('expires_at < :now', { now })
      .execute();
    const n = res.affected ?? 0;
    if (n > 0) {
      this.log.log(`Истекло приглашений (pending→expired): ${n}`);
    }
  }
}
