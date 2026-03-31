import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, IsNull } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { randomUUID, randomBytes } from 'crypto';
import { User } from '../users/user.entity';
import { UserSession } from './user-session.entity';
import { AuthSecurityEventService } from './auth-security-event.service';

export type JwtAudience = 'client' | 'business';

export interface SessionDeviceMeta {
  deviceId?: string | null;
  deviceName?: string | null;
  platform?: string | null;
  userAgent?: string | null;
  ip?: string | null;
}

export interface TokenPair {
  access_token: string;
  refresh_token: string;
  session_id: string;
  expires_in: number;
}

export interface RefreshResult extends TokenPair {
  userId: string;
}

@Injectable()
export class AuthSessionService {
  private readonly refreshBcryptRounds = 10;

  constructor(
    @InjectRepository(UserSession) private readonly repo: Repository<UserSession>,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly securityEvents: AuthSecurityEventService,
  ) {}

  private pepper(): string {
    return this.config.get<string>('REFRESH_TOKEN_PEPPER') || '';
  }

  private hashKey(sessionId: string, secret: string): string {
    return `${this.pepper()}${sessionId}:${secret}`;
  }

  parseRefreshToken(refreshToken: string): { sessionId: string; secret: string } | null {
    const t = refreshToken.trim();
    const dot = t.indexOf('.');
    if (dot <= 0 || dot >= t.length - 1) return null;
    const sessionId = t.slice(0, dot);
    const secret = t.slice(dot + 1);
    if (!/^[0-9a-f-]{36}$/i.test(sessionId) || !secret) return null;
    return { sessionId, secret };
  }

  private accessExpiresIn(): string {
    return this.config.get<string>('JWT_ACCESS_EXPIRES_IN') || this.config.get<string>('JWT_EXPIRES_IN') || '15m';
  }

  private accessExpiresInSeconds(): number {
    const raw = this.accessExpiresIn();
    if (raw.endsWith('m')) return parseInt(raw.slice(0, -1), 10) * 60;
    if (raw.endsWith('h')) return parseInt(raw.slice(0, -1), 10) * 3600;
    if (raw.endsWith('d')) return parseInt(raw.slice(0, -1), 10) * 86400;
    const n = parseInt(raw, 10);
    return Number.isFinite(n) ? n : 900;
  }

  async createSession(user: User, audience: JwtAudience, meta: SessionDeviceMeta): Promise<TokenPair> {
    const sessionId = randomUUID();
    const familyId = randomUUID();
    const secret = randomBytes(32).toString('hex');
    const refreshPlain = `${sessionId}.${secret}`;
    const refreshHash = await bcrypt.hash(this.hashKey(sessionId, secret), this.refreshBcryptRounds);

    const row = this.repo.create({
      id: sessionId,
      familyId,
      userId: user.id,
      refreshHash,
      deviceId: meta.deviceId ?? null,
      deviceName: meta.deviceName ?? null,
      platform: meta.platform ?? null,
      userAgent: meta.userAgent ?? null,
      ip: meta.ip ?? null,
      lastSeenAt: new Date(),
      revokedAt: null,
      replacedBySessionId: null,
      jwtAudience: audience,
    });
    await this.repo.save(row);

    const expiresIn = this.accessExpiresInSeconds();
    const access_token = await this.jwt.signAsync(
      { sub: user.id, sid: sessionId, aud: audience },
      { expiresIn: this.accessExpiresIn() },
    );

    return {
      access_token,
      refresh_token: refreshPlain,
      session_id: sessionId,
      expires_in: expiresIn,
    };
  }

  async refreshTokens(
    refreshToken: string,
    audience: JwtAudience,
    meta: SessionDeviceMeta,
  ): Promise<RefreshResult> {
    const parsed = this.parseRefreshToken(refreshToken);
    if (!parsed) throw new UnauthorizedException('Неверный refresh token');

    const { sessionId, secret } = parsed;
    const session = await this.repo.findOne({ where: { id: sessionId } });
    if (!session) throw new UnauthorizedException('Сессия не найдена');

    const key = this.hashKey(sessionId, secret);
    const match = await bcrypt.compare(key, session.refreshHash);
    if (!match) throw new UnauthorizedException('Неверный refresh token');

    if (session.jwtAudience !== audience) {
      throw new UnauthorizedException('Неверная аудитория токена');
    }

    if (session.revokedAt) {
      await this.revokeFamily(session.familyId, session.userId);
      await this.securityEvents.record(session.userId, 'refresh_reuse_detected', {
        sessionId: session.id,
        ip: meta.ip ?? null,
        userAgent: meta.userAgent ?? null,
      });
      throw new UnauthorizedException('Токен отозван (возможна компрометация)');
    }

    const newSessionId = randomUUID();
    const newSecret = randomBytes(32).toString('hex');
    const newPlain = `${newSessionId}.${newSecret}`;
    const newHash = await bcrypt.hash(this.hashKey(newSessionId, newSecret), this.refreshBcryptRounds);

    session.revokedAt = new Date();
    session.replacedBySessionId = newSessionId;
    await this.repo.save(session);

    const newRow = this.repo.create({
      id: newSessionId,
      familyId: session.familyId,
      userId: session.userId,
      refreshHash: newHash,
      deviceId: meta.deviceId ?? session.deviceId,
      deviceName: meta.deviceName ?? session.deviceName,
      platform: meta.platform ?? session.platform,
      userAgent: meta.userAgent ?? session.userAgent,
      ip: meta.ip ?? session.ip,
      lastSeenAt: new Date(),
      revokedAt: null,
      replacedBySessionId: null,
      jwtAudience: audience,
    });
    await this.repo.save(newRow);

    const userId = session.userId;
    const expiresIn = this.accessExpiresInSeconds();
    const access_token = await this.jwt.signAsync(
      { sub: userId, sid: newSessionId, aud: audience },
      { expiresIn: this.accessExpiresIn() },
    );

    await this.securityEvents.record(userId, 'refresh_rotated', {
      sessionId: newSessionId,
      ip: meta.ip ?? null,
      userAgent: meta.userAgent ?? null,
    });

    return {
      access_token,
      refresh_token: newPlain,
      session_id: newSessionId,
      expires_in: expiresIn,
      userId,
    };
  }

  async revokeByRefreshToken(refreshToken: string): Promise<{ userId: string } | null> {
    const parsed = this.parseRefreshToken(refreshToken);
    if (!parsed) return null;
    const session = await this.repo.findOne({ where: { id: parsed.sessionId } });
    if (!session || session.revokedAt) return session ? { userId: session.userId } : null;
    const key = this.hashKey(parsed.sessionId, parsed.secret);
    const match = await bcrypt.compare(key, session.refreshHash);
    if (!match) return null;
    session.revokedAt = new Date();
    await this.repo.save(session);
    await this.securityEvents.record(session.userId, 'logout', {
      sessionId: session.id,
    });
    return { userId: session.userId };
  }

  async revokeSession(userId: string, sessionId: string): Promise<boolean> {
    const session = await this.repo.findOne({ where: { id: sessionId, userId } });
    if (!session || session.revokedAt) return false;
    session.revokedAt = new Date();
    await this.repo.save(session);
    await this.securityEvents.record(userId, 'session_revoked', { sessionId });
    return true;
  }

  async revokeAllForUser(userId: string): Promise<number> {
    const res = await this.repo
      .createQueryBuilder()
      .update(UserSession)
      .set({ revokedAt: () => 'NOW()' })
      .where('user_id = :userId', { userId })
      .andWhere('revoked_at IS NULL')
      .execute();
    await this.securityEvents.record(userId, 'logout_all', {});
    return res.affected ?? 0;
  }

  async revokeAllExcept(userId: string, exceptSessionId: string): Promise<number> {
    const res = await this.repo
      .createQueryBuilder()
      .update(UserSession)
      .set({ revokedAt: () => 'NOW()' })
      .where('user_id = :userId', { userId })
      .andWhere('id != :except', { except: exceptSessionId })
      .andWhere('revoked_at IS NULL')
      .execute();
    await this.securityEvents.record(userId, 'sessions_revoked_all_except', {
      metadata: { except_session_id: exceptSessionId },
    });
    return res.affected ?? 0;
  }

  private async revokeFamily(familyId: string, userId: string): Promise<void> {
    await this.repo
      .createQueryBuilder()
      .update(UserSession)
      .set({ revokedAt: () => 'NOW()' })
      .where('family_id = :familyId', { familyId })
      .andWhere('user_id = :userId', { userId })
      .andWhere('revoked_at IS NULL')
      .execute();
  }

  async assertSessionActive(sessionId: string, userId: string): Promise<UserSession | null> {
    return this.repo.findOne({
      where: { id: sessionId, userId, revokedAt: IsNull() },
    });
  }

  async listSessions(userId: string, currentSessionId: string | null) {
    const rows = await this.repo.find({
      where: { userId },
      order: { createdAt: 'DESC' },
      take: 50,
    });
    return rows.map((r) => ({
      id: r.id,
      created_at: r.createdAt instanceof Date ? r.createdAt.toISOString() : r.createdAt,
      last_seen_at: r.lastSeenAt ? (r.lastSeenAt instanceof Date ? r.lastSeenAt.toISOString() : r.lastSeenAt) : null,
      device_name: r.deviceName,
      platform: r.platform,
      revoked: r.revokedAt != null,
      is_current: currentSessionId != null && r.id === currentSessionId,
    }));
  }

  async touchSession(sessionId: string, userId: string): Promise<void> {
    await this.repo.update({ id: sessionId, userId, revokedAt: IsNull() }, { lastSeenAt: new Date() });
  }
}
