import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
  forwardRef,
} from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';
import { randomUUID } from 'crypto';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { User, BusinessRole, AccountRealm } from './user.entity';
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
import { Chat } from '../chats/chat.entity';
import { Order } from '../orders/order.entity';

export interface OrganizationSummaryDto {
  id: string;
  name: string;
  role: string;
  plan_key?: string;
}

const USER_AVATAR_DIR = path.join(process.cwd(), 'uploads', 'user-avatars');

function clearUserAvatarFiles(userId: string): void {
  const dir = path.join(USER_AVATAR_DIR, userId);
  if (!fs.existsSync(dir)) return;
  for (const name of fs.readdirSync(dir)) {
    const lower = name.toLowerCase();
    if (!lower.startsWith('avatar')) continue;
    try {
      fs.unlinkSync(path.join(dir, name));
    } catch {
      /* ignore */
    }
  }
}

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User) private repo: Repository<User>,
    @InjectRepository(UserOrganizationMembership) private membershipRepo: Repository<UserOrganizationMembership>,
    @InjectRepository(StaffMember) private staffRepo: Repository<StaffMember>,
    @InjectRepository(OrganizationInvitation) private invitationRepo: Repository<OrganizationInvitation>,
    @InjectRepository(Chat) private chatRepo: Repository<Chat>,
    @InjectRepository(Order) private orderRepo: Repository<Order>,
    @Inject(forwardRef(() => OrganizationsService)) private orgService: OrganizationsService,
    private readonly dataSource: DataSource,
  ) {}

  /**
   * Сотрудник организации может скачать аватар клиента, если с этим телефоном есть чат или заказ в своей организации.
   * Иначе GET /profile/avatar/:userId/... отдаёт только владельцу файла.
   */
  async canStaffFetchClientAvatar(viewer: User, avatarOwnerUserId: string): Promise<boolean> {
    if (!viewer || !avatarOwnerUserId) return false;
    if (viewer.id === avatarOwnerUserId) return true;
    if (viewer.accountRealm !== 'business' || !viewer.organizationId) return false;
    const target = await this.repo.findOne({
      where: { id: avatarOwnerUserId },
      select: ['id', 'accountRealm', 'phone'],
    });
    if (!target || target.accountRealm !== 'client') return false;
    const tKey = this.clientPhoneMatchKey(target.phone || '');
    if (!tKey) return false;
    const orgId = viewer.organizationId;

    const chats = await this.chatRepo.find({
      where: { organizationId: orgId },
      select: ['clientPhone'],
    });
    for (const c of chats) {
      if (this.clientPhoneMatchKey(c.clientPhone || '') === tKey) return true;
    }

    const rows = await this.orderRepo
      .createQueryBuilder('o')
      .select('DISTINCT o.client_phone', 'phone')
      .where('o.organization_id = :orgId', { orgId })
      .andWhere('o.client_phone IS NOT NULL')
      .andWhere("TRIM(o.client_phone) <> ''")
      .getRawMany<{ phone: string }>();
    for (const r of rows) {
      if (this.clientPhoneMatchKey(r.phone || '') === tKey) return true;
    }
    return false;
  }

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
      avatar_url: user.avatarUrl ?? null,
      account_realm: user.accountRealm ?? 'business',
      role: user.role,
      organization_id: user.organizationId,
      organizations: organizations ?? [],
    };
  }

  /**
   * Права из карточки персонала (staff_members) для master/admin.
   * Владелец и самозанятый — полный доступ независимо от записи staff.
   */
  async appendStaffCapabilities(user: User, payload: Record<string, unknown>): Promise<void> {
    const orgId = user.organizationId?.trim();
    if (!orgId) return;
    const role = user.role;
    if (role === 'owner' || role === 'solo') {
      payload['staff_capabilities'] = {
        can_see_chats: true,
        can_write_chats: true,
        can_manage_org_settings: true,
      };
      return;
    }
    const staff = await this.staffRepo.findOne({
      where: { userId: user.id, organizationId: orgId },
    });
    if (!staff) {
      if (role === 'admin') {
        payload['staff_capabilities'] = {
          can_see_chats: true,
          can_write_chats: true,
          can_manage_org_settings: true,
        };
      } else {
        payload['staff_capabilities'] = {
          can_see_chats: false,
          can_write_chats: false,
          can_manage_org_settings: false,
        };
      }
      return;
    }
    const s = staff as StaffMember & {
      canSeeChats?: boolean;
      canWriteChats?: boolean;
      canManageOrgSettings?: boolean;
    };
    payload['staff_capabilities'] = {
      can_see_chats: s.canSeeChats === true,
      can_write_chats: s.canWriteChats === true,
      can_manage_org_settings: s.canManageOrgSettings === true,
    };
  }

  /** Сохранить аватар текущего пользователя (jpeg/png/webp, до ~5 МБ). */
  async saveUserAvatar(userId: string, file: Express.Multer.File): Promise<User> {
    const user = await this.repo.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('Пользователь не найден');
    const extRaw = path.extname(file.originalname || '').toLowerCase();
    const ext = extRaw && extRaw.length <= 6 && /^\.[a-z0-9]+$/.test(extRaw) ? extRaw : '.jpg';
    const allowed = ['.jpg', '.jpeg', '.png', '.webp'];
    if (!allowed.includes(ext)) {
      throw new BadRequestException('Допустимы изображения: jpg, png, webp');
    }
    const filename = `avatar-${randomUUID()}${ext}`;
    const dir = path.join(USER_AVATAR_DIR, userId);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    clearUserAvatarFiles(userId);
    const filePath = path.join(dir, filename);
    if (file.buffer?.length) {
      fs.writeFileSync(filePath, file.buffer);
    } else if (file.path && fs.existsSync(file.path)) {
      fs.copyFileSync(file.path, filePath);
    } else {
      throw new BadRequestException('Пустой файл');
    }
    const baseUrl = process.env.API_BASE_URL || 'http://localhost:3000/api/v1';
    const url = `${baseUrl}/profile/avatar/${userId}/${encodeURIComponent(filename)}`;
    user.avatarUrl = url;
    await this.repo.save(user);
    return user;
  }

  getUserAvatarFilePath(userId: string, filename: string): string | null {
    const safeName = path.basename(filename);
    if (!safeName || safeName.includes('..')) return null;
    const fullPath = path.join(USER_AVATAR_DIR, userId, safeName);
    if (!fs.existsSync(fullPath)) return null;
    return fullPath;
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
    if (user.accountRealm !== 'business') {
      throw new ForbiddenException('Смена организации доступна только в бизнес-аккаунте');
    }
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
    if (user.accountRealm !== 'business') {
      throw new ForbiddenException('Создание организации доступно только в бизнес-приложении');
    }
    if (!(await this.canCreateAdditionalOrganization(user))) {
      throw new ForbiddenException('Создавать организации могут владелец или самозанятый');
    }
    const org = await this.orgService.createOrganizationWithDefaults(dto);
    await this.ensureMembership(userId, org.id, 'owner');
    user.organizationId = org.id;
    /** Самозанятый остаётся solo в JWT: в организации он мастер (staff создаётся при первом GET /staff). */
    if (user.role !== 'solo') {
      user.role = 'owner';
    }
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

  private assertClientRealm(user: User): void {
    if (user.accountRealm !== 'client') {
      throw new ForbiddenException('Доступно только для клиентского аккаунта');
    }
  }

  async getClientAppState(userId: string): Promise<{
    payload: Record<string, unknown> | null;
    updated_at: string | null;
  }> {
    const u = await this.repo.findOne({
      where: { id: userId },
      select: ['id', 'accountRealm', 'clientAppState', 'clientAppStateUpdatedAt'],
    });
    if (!u) throw new NotFoundException('Пользователь не найден');
    if (u.accountRealm !== 'client') {
      return { payload: null, updated_at: null };
    }
    return {
      payload: (u.clientAppState as Record<string, unknown> | null) ?? null,
      updated_at: u.clientAppStateUpdatedAt ? u.clientAppStateUpdatedAt.toISOString() : null,
    };
  }

  async putClientAppState(
    userId: string,
    payload: Record<string, unknown>,
  ): Promise<{ ok: true; updated_at: string }> {
    const u = await this.repo.findOne({ where: { id: userId } });
    if (!u) throw new NotFoundException('Пользователь не найден');
    this.assertClientRealm(u);
    const json = JSON.stringify(payload);
    const max = 600 * 1024;
    if (json.length > max) {
      throw new BadRequestException(`Слишком большой объём настроек (>${max} байт)`);
    }
    u.clientAppState = payload;
    u.clientAppStateUpdatedAt = new Date();
    await this.repo.save(u);
    return { ok: true, updated_at: u.clientAppStateUpdatedAt.toISOString() };
  }

  /**
   * Телефон в чатах/заказах — только цифры; сравниваем с users.phone (8→7).
   * По умолчанию ищем клиентский аккаунт (пуши и лента клиента).
   */
  async findIdByNormalizedPhone(phoneDigits: string, realm: AccountRealm = 'client'): Promise<string | null> {
    if (!phoneDigits) return null;
    const norm = (p: string) => {
      const d = String(p || '').replace(/\D/g, '');
      if (d.length === 11 && d.startsWith('8')) return '7' + d.slice(1);
      return d;
    };
    const users = await this.repo.find({ where: { accountRealm: realm }, select: ['id', 'phone'] });
    for (const row of users) {
      if (row.phone != null && norm(row.phone) === phoneDigits) return row.id;
    }
    return null;
  }

  /**
   * Ключ для сопоставления телефона чата (`client_phone` — часто только цифры) с `users.phone` клиента.
   */
  clientPhoneMatchKey(raw: string): string {
    const d = String(raw || '').replace(/\D/g, '');
    if (d.length === 11 && d.startsWith('8')) return '7' + d.slice(1);
    if (d.length === 10) return '7' + d;
    return d;
  }

  /** Для списка чатов СТО/поддержки: avatar_url клиентских аккаунтов по ключу телефона. */
  async mapClientAvatarUrlsByPhoneKeys(keys: Set<string>): Promise<Map<string, string | null>> {
    const m = new Map<string, string | null>();
    for (const k of keys) m.set(k, null);
    if (keys.size === 0) return m;
    const users = await this.repo.find({
      where: { accountRealm: 'client' },
      select: ['phone', 'avatarUrl'],
    });
    for (const u of users) {
      if (u.phone == null) continue;
      const uk = this.clientPhoneMatchKey(u.phone);
      if (keys.has(uk)) m.set(uk, u.avatarUrl ?? null);
    }
    return m;
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

  /** Найти бизнес-аккаунт по контактам из приглашения (email/телефон нормализованы). */
  async findUserIdForInviteContact(emailNorm: string | null, phoneNorm: string | null): Promise<string | null> {
    if (emailNorm) {
      const u = await this.repo.findOne({ where: { email: emailNorm, accountRealm: 'business' } });
      if (u) return u.id;
    }
    if (phoneNorm) {
      return this.findIdByNormalizedPhone(phoneNorm, 'business');
    }
    return null;
  }

  async getIncomingInvitations(userId: string) {
    const u = await this.findById(userId);
    if (!u) throw new NotFoundException('Пользователь не найден');
    if (u.accountRealm !== 'business') return { items: [] };
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
    if (u.accountRealm !== 'business') {
      throw new ForbiddenException('Приглашения в организацию доступны только в бизнес-аккаунте');
    }
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
      // Проверки emailVerifiedAt / phoneVerifiedAt отключены, пока в приложении нет обязательного подтверждения контактов.

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

    try {
      await this.orgService.promoteSoloToOwnerIfNeeded(result);
    } catch (e) {
      /* не блокируем принятие приглашения */
    }

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
    if (u.accountRealm !== 'business') {
      throw new ForbiddenException('Приглашения в организацию доступны только в бизнес-аккаунте');
    }
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
      const realm = (user.accountRealm ?? 'business') as AccountRealm;
      const ownerId = await this.findIdByNormalizedPhone(digits, realm);
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

  /** Та же нормализация, что в OrdersService.normalizePhoneForCompare (сопоставление с client_phone в заказах). */
  private normalizePhoneForOrdersCompare(phone: string): string {
    const digits = String(phone || '').replace(/\D/g, '');
    if (digits.length === 11 && digits.startsWith('8')) return '7' + digits.slice(1);
    return digits;
  }

  /** Авто из заказов по телефону пользователя (для Control Center). */
  async getOrderCarsSummaryForInternalUser(phone: string | null): Promise<
    Array<{
      car_id: string;
      car_info: string;
      vin: string | null;
      license_plate: string | null;
      car_photo_url: string | null;
      orders_count: number;
      last_order_at: string;
    }>
  > {
    if (!phone) return [];
    const norm = this.normalizePhoneForOrdersCompare(phone);
    const rows = await this.orderRepo.find({ order: { dateTime: 'DESC' } });
    const map = new Map<
      string,
      {
        car_id: string;
        car_info: string;
        vin: string | null;
        license_plate: string | null;
        car_photo_url: string | null;
        orders_count: number;
        last_order_at: string;
      }
    >();
    for (const o of rows) {
      const p = this.normalizePhoneForOrdersCompare((o as any).clientPhone || '');
      if (p !== norm) continue;
      const carId = String((o as any).carId || '').trim();
      if (!carId) continue;
      if (!map.has(carId)) {
        const dt = (o as any).dateTime as Date;
        map.set(carId, {
          car_id: carId,
          car_info: (o as any).carInfo || '',
          vin: (o as any).vin ?? null,
          license_plate: (o as any).licensePlate ?? null,
          car_photo_url: (o as any).carPhotoUrl ?? null,
          orders_count: 1,
          last_order_at: dt instanceof Date ? dt.toISOString() : String(dt),
        });
      } else {
        map.get(carId)!.orders_count += 1;
      }
    }
    return [...map.values()].sort((a, b) => b.last_order_at.localeCompare(a.last_order_at));
  }

  async getInternalUserDetail(userId: string) {
    const user = await this.findById(userId);
    if (!user) throw new NotFoundException('Пользователь не найден');
    const isBusiness = user.organizationId != null || user.role !== 'solo';
    const ROLE_LABELS: Record<BusinessRole, string> = {
      owner: 'Владелец',
      admin: 'Администратор',
      master: 'Мастер',
      solo: 'Клиент',
    };
    const cars = await this.getOrderCarsSummaryForInternalUser(user.phone);
    return {
      id: user.id,
      phone: user.phone,
      email: user.email,
      name: user.name,
      role: user.role,
      role_label: ROLE_LABELS[user.role] ?? user.role,
      account_type: isBusiness ? 'business' : 'client',
      account_realm: user.accountRealm ?? 'business',
      organization_id: user.organizationId,
      organization_name: user.organization?.name ?? null,
      avatar_url: user.avatarUrl ?? null,
      cars_from_orders: cars,
    };
  }

  async updateInternalUserDisplayName(userId: string, name: string): Promise<boolean> {
    const user = await this.repo.findOne({ where: { id: userId } });
    if (!user) return false;
    const n = name.trim().slice(0, 255);
    if (!n) return false;
    user.name = n;
    await this.repo.save(user);
    return true;
  }

  async clearUserAvatar(userId: string): Promise<boolean> {
    const user = await this.repo.findOne({ where: { id: userId } });
    if (!user) return false;
    const dir = path.join(USER_AVATAR_DIR, userId);
    try {
      if (fs.existsSync(dir)) fs.rmSync(dir, { recursive: true, force: true });
    } catch {
      // ignore
    }
    user.avatarUrl = null;
    await this.repo.save(user);
    return true;
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
