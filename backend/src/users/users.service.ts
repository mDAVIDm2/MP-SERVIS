import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
  forwardRef,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { User, BusinessRole } from './user.entity';
import { UserSession } from '../auth/user-session.entity';
import { SecurityEvent } from '../auth/security-event.entity';
import { Notification } from '../notifications/notification.entity';
import { PushDevice } from '../notifications/push-device.entity';
import {
  ClientNotificationPreferences,
  mergeClientNotificationPrefs,
} from '../notifications/client-notification-preferences';
import { UserOrganizationMembership } from './user-organization-membership.entity';
import { StaffMember } from '../organizations/staff-member.entity';
import { OrganizationsService } from '../organizations/organizations.service';
import { OrganizationInvitation } from '../organizations/organization-invitation.entity';

export interface OrganizationSummaryDto {
  id: string;
  name: string;
  role: string;
  plan_key?: string;
}

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User) private repo: Repository<User>,
    @InjectRepository(UserOrganizationMembership) private membershipRepo: Repository<UserOrganizationMembership>,
    @InjectRepository(StaffMember) private staffRepo: Repository<StaffMember>,
    @InjectRepository(OrganizationInvitation) private invitationRepo: Repository<OrganizationInvitation>,
    @Inject(forwardRef(() => OrganizationsService)) private orgService: OrganizationsService,
    private readonly dataSource: DataSource,
  ) {}

  async findById(id: string): Promise<User | null> {
    return this.repo.findOne({ where: { id }, relations: ['organization'] });
  }

  async findAll(): Promise<User[]> {
    return this.repo.find({
      relations: ['organization'],
      order: { name: 'ASC', phone: 'ASC' },
    });
  }

  profileResponse(user: User, organizations?: OrganizationSummaryDto[]) {
    return {
      id: user.id,
      email: user.email,
      email_verified_at: user.emailVerifiedAt ? user.emailVerifiedAt.toISOString() : null,
      phone: user.phone,
      phone_verified_at: user.phoneVerifiedAt ? user.phoneVerifiedAt.toISOString() : null,
      name: user.name,
      role: user.role,
      organization_id: user.organizationId,
      organizations: organizations ?? [],
    };
  }

  /** Поддержка связи пользователь–организация (владелец). Идемпотентно. */
  async ensureMembership(userId: string, organizationId: string | null | undefined, role: string): Promise<void> {
    if (!organizationId) return;
    const exists = await this.membershipRepo.findOne({ where: { userId, organizationId } });
    if (exists) return;
    await this.membershipRepo.save(
      this.membershipRepo.create({ userId, organizationId, role: role || 'owner' }),
    );
  }

  async getOrganizationSummariesForUser(user: User): Promise<OrganizationSummaryDto[]> {
    const map = new Map<string, OrganizationSummaryDto>();

    const memberships = await this.membershipRepo.find({
      where: { userId: user.id },
      relations: ['organization'],
    });
    for (const m of memberships) {
      const o = m.organization;
      map.set(m.organizationId, {
        id: m.organizationId,
        name: o?.name ?? 'Организация',
        role: m.role,
      });
    }

    const staffRows = await this.staffRepo.find({
      where: { userId: user.id },
      relations: ['organization'],
    });
    for (const s of staffRows) {
      if (!s.organizationId || map.has(s.organizationId)) continue;
      const o = s.organization;
      map.set(s.organizationId, {
        id: s.organizationId,
        name: o?.name ?? 'Организация',
        role: s.role || 'master',
      });
    }

    if (user.organizationId && !map.has(user.organizationId)) {
      const org = await this.orgService.findOne(user.organizationId);
      if (org) {
        map.set(org.id, { id: org.id, name: org.name, role: user.role });
      }
    }

    const orgIds = [...map.keys()];
    const planKeys = await this.orgService.getPlanKeysForOrganizations(orgIds);
    for (const oid of orgIds) {
      const row = map.get(oid);
      if (row) row.plan_key = planKeys[oid] ?? 'team';
    }

    return [...map.values()].sort((a, b) => a.name.localeCompare(b.name, 'ru'));
  }

  async canAccessOrganization(userId: string, organizationId: string): Promise<boolean> {
    const m = await this.membershipRepo.findOne({ where: { userId, organizationId } });
    if (m) return true;
    const staff = await this.staffRepo.findOne({ where: { userId, organizationId } });
    return !!staff;
  }

  async switchActiveOrganization(userId: string, organizationId: string): Promise<User> {
    const user = await this.findById(userId);
    if (!user) throw new NotFoundException('Пользователь не найден');
    if (!(await this.canAccessOrganization(userId, organizationId))) {
      throw new ForbiddenException('Нет доступа к этой организации');
    }

    const membership = await this.membershipRepo.findOne({ where: { userId, organizationId } });
    let nextRole: BusinessRole = user.role;
    if (membership) {
      nextRole = membership.role as BusinessRole;
    } else {
      const staff = await this.staffRepo.findOne({ where: { userId, organizationId } });
      if (staff?.role) nextRole = staff.role as BusinessRole;
    }

    user.organizationId = organizationId;
    user.role = nextRole;
    await this.repo.save(user);
    const fresh = await this.findById(userId);
    return fresh!;
  }

  private async canCreateAdditionalOrganization(user: User): Promise<boolean> {
    if (user.role === 'owner' || user.role === 'solo') return true;
    const ownerMembership = await this.membershipRepo.findOne({ where: { userId: user.id, role: 'owner' } });
    return !!ownerMembership;
  }

  async createOwnedOrganization(
    userId: string,
    dto: { name: string; address?: string; phone?: string; plan_key?: string },
  ): Promise<{ user: User; summaries: OrganizationSummaryDto[] }> {
    const user = await this.findById(userId);
    if (!user) throw new NotFoundException('Пользователь не найден');
    if (!(await this.canCreateAdditionalOrganization(user))) {
      throw new ForbiddenException('Создавать организации могут владелец или самозанятый');
    }
    const org = await this.orgService.createOrganizationWithDefaults(dto);
    await this.ensureMembership(userId, org.id, 'owner');
    user.organizationId = org.id;
    user.role = 'owner';
    await this.repo.save(user);
    const fresh = await this.findById(userId);
    const summaries = await this.getOrganizationSummariesForUser(fresh!);
    return { user: fresh!, summaries };
  }

  async getNotificationPreferences(userId: string): Promise<ClientNotificationPreferences> {
    const u = await this.findById(userId);
    if (!u) throw new NotFoundException('Пользователь не найден');
    return mergeClientNotificationPrefs((u as any).notificationPreferences);
  }

  async updateNotificationPreferences(
    userId: string,
    patch: Partial<ClientNotificationPreferences>,
  ): Promise<ClientNotificationPreferences> {
    const u = await this.findById(userId);
    if (!u) throw new NotFoundException('Пользователь не найден');
    const cur = mergeClientNotificationPrefs((u as any).notificationPreferences);
    const next: ClientNotificationPreferences = { ...cur, ...patch };
    (u as any).notificationPreferences = next;
    await this.repo.save(u);
    return next;
  }

  /** Телефон в чатах/заказах — только цифры; сравниваем с users.phone (8→7). */
  async findIdByNormalizedPhone(phoneDigits: string): Promise<string | null> {
    if (!phoneDigits) return null;
    const norm = (p: string) => {
      const d = String(p || '').replace(/\D/g, '');
      if (d.length === 11 && d.startsWith('8')) return '7' + d.slice(1);
      return d;
    };
    const users = await this.repo.find({ select: ['id', 'phone'] });
    for (const row of users) {
      if (row.phone != null && norm(row.phone) === phoneDigits) return row.id;
    }
    return null;
  }

  private normalizePhoneLoose(raw: string): string {
    const d = String(raw).replace(/\D/g, '');
    if (d.length === 11 && d.startsWith('8')) return '7' + d.slice(1);
    if (d.length === 10 && !d.startsWith('7')) return '7' + d;
    return d;
  }

  private normalizeEmail(raw?: string | null): string | null {
    if (!raw) return null;
    const e = String(raw).trim().toLowerCase();
    return e || null;
  }

  private invitationToDto(inv: OrganizationInvitation) {
    return {
      id: inv.id,
      organization_id: inv.organizationId,
      organization_name: inv.organization?.name ?? 'Организация',
      role: inv.role,
      invited_name: inv.invitedName,
      invited_email: inv.invitedEmail,
      invited_phone: inv.invitedPhone,
      message: inv.message,
      status: inv.status,
      created_at: inv.createdAt?.toISOString() ?? null,
      expires_at: inv.expiresAt?.toISOString() ?? null,
      responded_at: inv.respondedAt?.toISOString() ?? null,
    };
  }

  /** Найти пользователя по контактам из приглашения (email/телефон нормализованы). */
  async findUserIdForInviteContact(emailNorm: string | null, phoneNorm: string | null): Promise<string | null> {
    if (emailNorm) {
      const u = await this.repo.findOne({ where: { email: emailNorm } });
      if (u) return u.id;
    }
    if (phoneNorm) {
      return this.findIdByNormalizedPhone(phoneNorm);
    }
    return null;
  }

  async getIncomingInvitations(userId: string) {
    const u = await this.findById(userId);
    if (!u) throw new NotFoundException('Пользователь не найден');
    const emailNorm = this.normalizeEmail(u.email);
    const phoneNorm = u.phone ? this.normalizePhoneLoose(u.phone) : null;
    if (!emailNorm && !phoneNorm) return { items: [] };

    const now = new Date();
    const qb = this.invitationRepo
      .createQueryBuilder('inv')
      .leftJoinAndSelect('inv.organization', 'org')
      .where('inv.status = :status', { status: 'pending' })
      .andWhere('(inv.expires_at IS NULL OR inv.expires_at > :now)', { now });
    if (emailNorm && phoneNorm) {
      qb.andWhere('(inv.invited_email_norm = :email OR inv.invited_phone_norm = :phone)', {
        email: emailNorm,
        phone: phoneNorm,
      });
    } else if (emailNorm) {
      qb.andWhere('inv.invited_email_norm = :email', { email: emailNorm });
    } else if (phoneNorm) {
      qb.andWhere('inv.invited_phone_norm = :phone', { phone: phoneNorm });
    }
    const rows = await qb.orderBy('inv.created_at', 'DESC').getMany();
    return { items: rows.map((x) => this.invitationToDto(x)) };
  }

  async acceptInvitation(
    userId: string,
    invitationId: string,
    opts?: { set_active_organization?: boolean },
  ): Promise<{ user: User; summaries: OrganizationSummaryDto[] }> {
    const u = await this.findById(userId);
    if (!u) throw new NotFoundException('Пользователь не найден');
    const setActive = opts?.set_active_organization !== false;
    const emailNorm = this.normalizeEmail(u.email);
    const phoneNorm = u.phone ? this.normalizePhoneLoose(u.phone) : null;

    const result = await this.dataSource.transaction(async (em) => {
      const inviteRepo = em.getRepository(OrganizationInvitation);
      const membershipRepo = em.getRepository(UserOrganizationMembership);
      const staffRepo = em.getRepository(StaffMember);
      const userRepo = em.getRepository(User);

      const inv = await inviteRepo.findOne({ where: { id: invitationId } });
      if (!inv) throw new NotFoundException('Приглашение не найдено');
      if (inv.status !== 'pending') throw new BadRequestException('Приглашение уже обработано');
      if (inv.expiresAt && inv.expiresAt.getTime() < Date.now()) {
        inv.status = 'expired';
        inv.respondedAt = new Date();
        await inviteRepo.save(inv);
        throw new BadRequestException('Срок действия приглашения истёк');
      }

      const emailMatches = !!(emailNorm && inv.invitedEmailNorm && emailNorm === inv.invitedEmailNorm);
      const phoneMatches = !!(phoneNorm && inv.invitedPhoneNorm && phoneNorm === inv.invitedPhoneNorm);
      if (!emailMatches && !phoneMatches) {
        throw new ForbiddenException('Это приглашение не принадлежит вашему аккаунту');
      }
      if (emailMatches && !u.emailVerifiedAt) {
        throw new ForbiddenException('Подтвердите email, чтобы принять приглашение');
      }
      if (phoneMatches && !u.phoneVerifiedAt) {
        throw new ForbiddenException('Подтвердите телефон, чтобы принять приглашение');
      }

      const role = String(inv.role || 'master');
      const existingMembership = await membershipRepo.findOne({
        where: { userId, organizationId: inv.organizationId },
      });
      if (!existingMembership) {
        await membershipRepo.save(
          membershipRepo.create({
            userId,
            organizationId: inv.organizationId,
            role,
          }),
        );
      }

      const existingStaff = await staffRepo.findOne({
        where: { userId, organizationId: inv.organizationId },
      });
      let staffId: string | null = existingStaff?.id ?? null;
      if (!existingStaff) {
        const row = staffRepo.create({
          organizationId: inv.organizationId,
          userId,
          name: u.name || inv.invitedName || 'Сотрудник',
          phone: u.phone ?? inv.invitedPhone ?? null,
          email: u.email ?? inv.invitedEmail ?? null,
          role,
          isActive: true,
          invitedAt: new Date(),
          skills: [],
        });
        const saved = await staffRepo.save(row);
        staffId = saved.id;
      }

      inv.status = 'accepted';
      inv.acceptedByUserId = userId;
      inv.respondedAt = new Date();
      inv.staffMemberId = staffId;
      await inviteRepo.save(inv);

      if (setActive) {
        u.organizationId = inv.organizationId;
        u.role = role as BusinessRole;
        await userRepo.save(u);
      }
      return inv.organizationId;
    });

    const fresh = await this.findById(userId);
    const summaries = await this.getOrganizationSummariesForUser(fresh!);
    if (setActive && result && fresh) {
      fresh.organizationId = result;
    }
    return { user: fresh!, summaries };
  }

  async declineInvitation(userId: string, invitationId: string) {
    const u = await this.findById(userId);
    if (!u) throw new NotFoundException('Пользователь не найден');
    const emailNorm = this.normalizeEmail(u.email);
    const phoneNorm = u.phone ? this.normalizePhoneLoose(u.phone) : null;
    const inv = await this.invitationRepo.findOne({ where: { id: invitationId } });
    if (!inv) throw new NotFoundException('Приглашение не найдено');
    if (inv.status !== 'pending') throw new BadRequestException('Приглашение уже обработано');
    const emailMatches = !!(emailNorm && inv.invitedEmailNorm && emailNorm === inv.invitedEmailNorm);
    const phoneMatches = !!(phoneNorm && inv.invitedPhoneNorm && phoneNorm === inv.invitedPhoneNorm);
    if (!emailMatches && !phoneMatches) {
      throw new ForbiddenException('Это приглашение не принадлежит вашему аккаунту');
    }
    inv.status = 'declined';
    inv.respondedAt = new Date();
    await this.invitationRepo.save(inv);
    return this.invitationToDto(inv);
  }

  /** Обновление имени и неподтверждённого телефона (клиентское приложение). */
  async updateOwnProfile(userId: string, dto: { name?: string; phone?: string }): Promise<User> {
    const user = await this.findById(userId);
    if (!user) throw new NotFoundException('Пользователь не найден');
    if (dto.name != null) {
      const n = dto.name.trim();
      if (n.length > 0) user.name = n;
    }
    if (dto.phone != null && dto.phone.trim()) {
      const digits = this.normalizePhoneLoose(dto.phone);
      if (digits.length < 10 || digits.length > 15) {
        throw new BadRequestException('Некорректный номер телефона');
      }
      const ownerId = await this.findIdByNormalizedPhone(digits);
      if (ownerId != null && ownerId !== userId) {
        throw new ConflictException('Этот номер уже привязан к другому аккаунту. Укажите другой телефон.');
      }
      user.phone = digits;
      if (user.phoneVerifiedAt == null) user.phoneVerifiedAt = null;
    }
    try {
      await this.repo.save(user);
    } catch (e: unknown) {
      const err = e as { code?: string };
      if (err?.code === '23505') {
        throw new ConflictException('Этот номер уже привязан к другому аккаунту. Укажите другой телефон.');
      }
      throw e;
    }
    const fresh = await this.findById(userId);
    return fresh!;
  }

  /** Полное удаление аккаунта клиента и связанных данных (сессии, уведомления, устройства). */
  async deleteOwnAccount(userId: string): Promise<void> {
    await this.dataSource.transaction(async (em) => {
      await em.delete(UserSession, { userId });
      await em.delete(SecurityEvent, { userId });
      await em.delete(Notification, { userId });
      await em.delete(PushDevice, { userId });
      await em.delete(UserOrganizationMembership, { userId });
      await em.getRepository(StaffMember).update({ userId }, { userId: null });
      await em.delete(User, { id: userId });
    });
  }
}
