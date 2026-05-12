import { BadRequestException, ConflictException, forwardRef, Inject, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User, BusinessRole, AccountRealm } from '../users/user.entity';
import { Organization } from '../organizations/organization.entity';
import { UsersService } from '../users/users.service';
import { CarTransferService } from '../users/car-transfer.service';
import { AuthOtpService } from './auth-otp.service';
import { AuthSessionService, JwtAudience, SessionDeviceMeta } from './auth-session.service';
import { AuthSecurityEventService } from './auth-security-event.service';
import type { OtpRecipientKind } from './auth-otp-challenge.entity';

/** Тестовые роли по email/телефону — только dev/stage при ALLOW_TEST_AUTH. */
function isTestAuthAllowed(): boolean {
  if (process.env.NODE_ENV === 'production') return false;
  const v = (process.env.ALLOW_TEST_AUTH || '').trim().toLowerCase();
  return v === '1' || v === 'true' || v === 'yes';
}

const TEST_ORG_NAME = 'Тестовый автосервис';

const TEST_PHONES: Record<string, { role: BusinessRole; name: string }> = {
  '79001111111': { role: 'owner', name: 'Владелец (тест)' },
  '79002222222': { role: 'admin', name: 'Администратор (тест)' },
  '79003333333': { role: 'master', name: 'Мастер (тест)' },
  '79004444444': { role: 'solo', name: 'Самозанятый (тест)' },
  '79197341904': { role: 'owner', name: 'Владелец' },
};

/** Зеркало тестовых ролей для email-входа (business / staging). */
const TEST_EMAILS: Record<string, { role: BusinessRole; name: string }> = {
  'owner@mpservis.test': { role: 'owner', name: 'Владелец (тест)' },
  'admin@mpservis.test': { role: 'admin', name: 'Администратор (тест)' },
  'master@mpservis.test': { role: 'master', name: 'Мастер (тест)' },
  'solo@mpservis.test': { role: 'solo', name: 'Самозанятый (тест)' },
};

function userAuthJson(user: User, organizations: unknown[]) {
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
    organizations,
  };
}

function realmFromAudience(aud: JwtAudience): AccountRealm {
  return aud === 'business' ? 'business' : 'client';
}

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User)
    private userRepo: Repository<User>,
    @InjectRepository(Organization)
    private orgRepo: Repository<Organization>,
    private usersService: UsersService,
    @Inject(forwardRef(() => CarTransferService))
    private readonly carTransfers: CarTransferService,
    private otp: AuthOtpService,
    private sessions: AuthSessionService,
    private securityEvents: AuthSecurityEventService,
  ) {}

  private async getOrCreateTestOrg(): Promise<Organization> {
    let org = await this.orgRepo.findOne({ where: { name: TEST_ORG_NAME } });
    if (!org) {
      org = this.orgRepo.create({
        name: TEST_ORG_NAME,
        address: 'ул. Тестовая, 1',
        phone: '+7 900 000-00-00',
        workingHours: 'Пн–Пт 9:00–19:00',
      });
      await this.orgRepo.save(org);
    }
    return org;
  }

  /** Поиск по email без учёта регистра — в рамках одного приложения (client / business). */
  private async findUserByEmailNormalized(
    normalizedEmail: string,
    realm: AccountRealm,
    withOrganization = false,
  ): Promise<User | null> {
    const e = normalizedEmail.trim().toLowerCase();
    if (!e) return null;
    const qb = this.userRepo
      .createQueryBuilder('u')
      .where('u.email IS NOT NULL AND LOWER(TRIM(u.email)) = :e', { e })
      .andWhere('u.account_realm = :realm', { realm });
    if (withOrganization) {
      qb.leftJoinAndSelect('u.organization', 'organization');
    }
    return qb.getOne();
  }

  private async findUserByPhoneDigits(phoneDigits: string, realm: AccountRealm, withOrganization = false): Promise<User | null> {
    const qb = this.userRepo
      .createQueryBuilder('u')
      .where('u.phone = :p', { p: phoneDigits })
      .andWhere('u.account_realm = :realm', { realm });
    if (withOrganization) {
      qb.leftJoinAndSelect('u.organization', 'organization');
    }
    return qb.getOne();
  }

  async sendCode(params: {
    email?: string;
    phone?: string;
    channel?: string;
    ip: string | null;
    audience: JwtAudience;
  }) {
    const realm = realmFromAudience(params.audience);
    const base = await this.otp.createChallenge({
      email: params.email,
      phone: params.phone,
      requestedChannel: params.channel,
      ip: params.ip,
    });
    let accountExists = false;
    try {
      if (params.email != null && String(params.email).trim() !== '') {
        const e = this.otp.normalizeEmail(params.email);
        accountExists = !!(await this.findUserByEmailNormalized(e, realm));
      } else if (params.phone != null && String(params.phone).trim() !== '') {
        const p = this.otp.normalizePhoneDigits(params.phone);
        accountExists = !!(await this.userRepo.findOne({ where: { phone: p, accountRealm: realm }, select: ['id'] }));
      }
    } catch {
      /* не блокируем отправку кода */
    }
    return { ...base, account_exists: accountExists };
  }

  private applyPhoneUnverified(user: User, raw: string | undefined, otpKind: OtpRecipientKind): void {
    if (otpKind !== 'email' || raw == null || !String(raw).trim()) return;
    let digits: string;
    try {
      digits = this.otp.normalizePhoneDigits(raw);
    } catch {
      throw new BadRequestException('Некорректный номер телефона (неподтверждённый)');
    }
    if (user.phoneVerifiedAt != null) return;
    user.phone = digits;
    user.phoneVerifiedAt = null;
  }

  async verifyCode(
    dto: {
      email?: string;
      phone?: string;
      challenge_id: string;
      code: string;
      phone_unverified?: string;
      name?: string;
    },
    audience: JwtAudience,
    meta: SessionDeviceMeta,
  ) {
    let expectedRecipient: string;
    let expectedKind: OtpRecipientKind;
    if (dto.email != null && String(dto.email).trim() !== '') {
      expectedRecipient = this.otp.normalizeEmail(dto.email);
      expectedKind = 'email';
    } else if (dto.phone != null && String(dto.phone).trim() !== '') {
      expectedRecipient = this.otp.normalizePhoneDigits(dto.phone);
      expectedKind = 'phone';
    } else {
      throw new BadRequestException('Укажите email или phone (как при отправке кода)');
    }

    await this.otp.verifyChallenge(dto.challenge_id, dto.code, expectedRecipient, expectedKind);

    const realm = realmFromAudience(audience);
    let user: User | null = null;

    if (expectedKind === 'email') {
      user = await this.findUserByEmailNormalized(expectedRecipient, realm, true);
      const testEntry =
        audience === 'business' && isTestAuthAllowed() ? TEST_EMAILS[expectedRecipient] : undefined;

      if (!user) {
        if (!testEntry) {
          if (!dto.name?.trim()) throw new BadRequestException('Укажите имя');
          if (!dto.phone_unverified?.trim()) throw new BadRequestException('Укажите телефон');
          try {
            this.otp.normalizePhoneDigits(dto.phone_unverified);
          } catch {
            throw new BadRequestException('Некорректный номер телефона');
          }
        }
        const displayName = testEntry ? testEntry.name : dto.name!.trim();
        user = this.userRepo.create({
          email: expectedRecipient,
          emailVerifiedAt: new Date(),
          name: displayName,
          role: testEntry?.role ?? 'solo',
          phone: null,
          phoneVerifiedAt: null,
          organizationId: null,
          accountRealm: realm,
        });
        this.applyPhoneUnverified(user, dto.phone_unverified, 'email');
        if (testEntry) {
          const org = await this.getOrCreateTestOrg();
          user.organizationId = org.id;
          user.name = testEntry.name;
          user.role = testEntry.role;
        }
        try {
          await this.userRepo.save(user);
        } catch (e: unknown) {
          const err = e as { code?: string };
          if (err?.code === '23505') {
            throw new ConflictException(
              realm === 'client'
                ? 'Этот email или телефон уже занят в клиентском аккаунте'
                : 'Этот email или телефон уже занят в бизнес-аккаунте',
            );
          }
          throw e;
        }
      } else {
        user.email = expectedRecipient;
        if (!user.emailVerifiedAt) {
          user.emailVerifiedAt = new Date();
        }
        this.applyPhoneUnverified(user, dto.phone_unverified, 'email');
        if (testEntry) {
          const org = await this.getOrCreateTestOrg();
          user.role = testEntry.role;
          user.organizationId = org.id;
          user.name = testEntry.name;
        }
        try {
          await this.userRepo.save(user);
        } catch (e: unknown) {
          const err = e as { code?: string };
          if (err?.code === '23505') {
            throw new ConflictException(
              realm === 'client'
                ? 'Этот email или телефон уже занят в клиентском аккаунте'
                : 'Этот email или телефон уже занят в бизнес-аккаунте',
            );
          }
          throw e;
        }
      }
    } else {
      const n = expectedRecipient;
      const testEntry = audience === 'business' && isTestAuthAllowed() ? TEST_PHONES[n] : undefined;
      user = await this.findUserByPhoneDigits(n, realm, true);

      if (testEntry) {
        const org = await this.getOrCreateTestOrg();
        if (!user) {
          user = this.userRepo.create({
            phone: n,
            phoneVerifiedAt: new Date(),
            name: testEntry.name,
            role: testEntry.role,
            organizationId: org.id,
            email: null,
            emailVerifiedAt: null,
            accountRealm: realm,
          });
          await this.userRepo.save(user);
        } else {
          user.role = testEntry.role;
          user.organizationId = org.id;
          user.name = testEntry.name;
          user.phoneVerifiedAt = new Date();
          await this.userRepo.save(user);
        }
      } else {
        if (!user) {
          user = this.userRepo.create({
            phone: n,
            phoneVerifiedAt: new Date(),
            name: 'User',
            role: 'solo',
            email: null,
            emailVerifiedAt: null,
            organizationId: null,
            accountRealm: realm,
          });
          await this.userRepo.save(user);
        } else {
          user.phoneVerifiedAt = new Date();
          await this.userRepo.save(user);
        }
      }
    }

    if (user!.accountRealm === 'client' && user!.phone) {
      try {
        await this.carTransfers.linkPendingTransfersForNewUser(user!.id, user!.phone);
      } catch {
        /* не блокируем вход */
      }
    }

    if (user!.accountRealm === 'business') {
      await this.usersService.ensureMembership(user!.id, user!.organizationId ?? undefined, user!.role);
    }

    const pair = await this.sessions.createSession(user!, audience, meta);
    const organizations = await this.usersService.getOrganizationSummariesForUser(user!);

    await this.securityEvents.record(user!.id, 'login_success', {
      sessionId: pair.session_id,
      ip: meta.ip ?? null,
      userAgent: meta.userAgent ?? null,
    });

    const userPayload = userAuthJson(user!, organizations) as Record<string, unknown>;
    await this.usersService.appendStaffCapabilities(user!, userPayload);
    return {
      access_token: pair.access_token,
      refresh_token: pair.refresh_token,
      expires_in: pair.expires_in,
      session_id: pair.session_id,
      user: userPayload,
    };
  }

  async refresh(refreshToken: string, audience: JwtAudience, meta: SessionDeviceMeta) {
    const pair = await this.sessions.refreshTokens(refreshToken, audience, meta);
    const user = await this.userRepo.findOne({ where: { id: pair.userId }, relations: ['organization'] });
    if (!user) throw new Error('User not found');
    const organizations = await this.usersService.getOrganizationSummariesForUser(user);
    const userPayload = userAuthJson(user, organizations) as Record<string, unknown>;
    await this.usersService.appendStaffCapabilities(user, userPayload);
    return {
      access_token: pair.access_token,
      refresh_token: pair.refresh_token,
      expires_in: pair.expires_in,
      session_id: pair.session_id,
      user: userPayload,
    };
  }

  async logoutByRefresh(refreshToken: string): Promise<void> {
    await this.sessions.revokeByRefreshToken(refreshToken);
  }

  async logoutAllSessions(userId: string): Promise<number> {
    return this.sessions.revokeAllForUser(userId);
  }
}
