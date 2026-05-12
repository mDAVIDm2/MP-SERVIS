import { BadRequestException, HttpException, HttpStatus, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, MoreThan, IsNull } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { randomInt } from 'crypto';
import { AuthOtpChallenge, OtpChallengeStatus, OtpRecipientKind } from './auth-otp-challenge.entity';
import { OtpDeliveryAggregator } from './otp-delivery/otp-delivery.aggregator';

const DEFAULT_OTP_TTL_SEC = 300;
const DEFAULT_OTP_MAX_ATTEMPTS = 5;
const MAX_CHALLENGES_PER_RECIPIENT_PER_HOUR = 8;
const RESEND_COOLDOWN_MS = 60 * 1000;
const BCRYPT_ROUNDS = 10;

export interface CreateOtpParams {
  email?: string;
  phone?: string;
  /** Канал из запроса клиента (email | sms | console | …). */
  requestedChannel?: string;
  ip: string | null;
}

@Injectable()
export class AuthOtpService {
  constructor(
    @InjectRepository(AuthOtpChallenge) private readonly repo: Repository<AuthOtpChallenge>,
    private readonly delivery: OtpDeliveryAggregator,
    private readonly config: ConfigService,
  ) {}

  /** TTL challenge в мс (OTP_TTL_SECONDS, по умолчанию 300 с, допустимо 60–3600). */
  private otpTtlMs(): number {
    const raw = this.config.get<string>('OTP_TTL_SECONDS');
    const sec = raw != null && raw.trim() !== '' ? parseInt(raw, 10) : DEFAULT_OTP_TTL_SEC;
    const clamped = Number.isFinite(sec) ? Math.min(3600, Math.max(60, sec)) : DEFAULT_OTP_TTL_SEC;
    return clamped * 1000;
  }

  /** Макс. неверных попыток ввода кода (OTP_MAX_ATTEMPTS, по умолчанию 5, 3–20). */
  private otpMaxAttempts(): number {
    const raw = this.config.get<string>('OTP_MAX_ATTEMPTS');
    const n = raw != null && raw.trim() !== '' ? parseInt(raw, 10) : DEFAULT_OTP_MAX_ATTEMPTS;
    return Number.isFinite(n) ? Math.min(20, Math.max(3, n)) : DEFAULT_OTP_MAX_ATTEMPTS;
  }

  normalizeEmail(email: string): string {
    const e = email.trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e)) {
      throw new BadRequestException('Некорректный email');
    }
    if (e.length > 320) throw new BadRequestException('Email слишком длинный');
    return e;
  }

  normalizePhoneDigits(phone: string): string {
    const n = phone.replace(/\D/g, '');
    if (n.length < 10) throw new BadRequestException('Некорректный номер телефона');
    if (n.length === 11 && n.startsWith('8')) return '7' + n.slice(1);
    if (n.length === 10 && !n.startsWith('7')) return '7' + n;
    return n;
  }

  private resolveRecipient(params: CreateOtpParams): { recipient: string; recipientKind: OtpRecipientKind } {
    const hasEmail = params.email != null && String(params.email).trim() !== '';
    const hasPhone = params.phone != null && String(params.phone).trim() !== '';
    if (hasEmail === hasPhone) {
      throw new BadRequestException('Укажите ровно одно: email или phone');
    }
    if (hasEmail) {
      return { recipient: this.normalizeEmail(params.email!), recipientKind: 'email' };
    }
    return { recipient: this.normalizePhoneDigits(params.phone!), recipientKind: 'phone' };
  }

  private generateNumericCode(length: number): string {
    const min = 10 ** (length - 1);
    const max = 10 ** length - 1;
    return String(randomInt(min, max + 1));
  }

  async createChallenge(
    params: CreateOtpParams,
  ): Promise<{ challenge_id: string; expires_in: number; resend_after: number; debug_otp?: string }> {
    const { recipient, recipientKind } = this.resolveRecipient(params);
    const requestedChannel = (params.requestedChannel || (recipientKind === 'email' ? 'email' : 'sms')).toLowerCase();

    const hourAgo = new Date(Date.now() - 60 * 60 * 1000);
    const recent = await this.repo.count({
      where: { recipient, recipientKind, createdAt: MoreThan(hourAgo) },
    });
    if (recent >= MAX_CHALLENGES_PER_RECIPIENT_PER_HOUR) {
      throw new HttpException('Слишком много запросов кода. Попробуйте позже.', HttpStatus.TOO_MANY_REQUESTS);
    }

    const last = await this.repo.findOne({
      where: { recipient, recipientKind },
      order: { createdAt: 'DESC' },
    });
    if (
      last &&
      last.status === 'pending' &&
      last.expiresAt.getTime() > Date.now() &&
      Date.now() - last.createdAt.getTime() < RESEND_COOLDOWN_MS
    ) {
      const waitSec = Math.ceil((RESEND_COOLDOWN_MS - (Date.now() - last.createdAt.getTime())) / 1000);
      throw new HttpException(`Повторная отправка через ${waitSec} с`, HttpStatus.TOO_MANY_REQUESTS);
    }

    await this.repo.update(
      { recipient, recipientKind, status: 'pending' as OtpChallengeStatus, consumedAt: IsNull() },
      { status: 'consumed', consumedAt: new Date() },
    );

    const ttlMs = this.otpTtlMs();
    const code = this.generateNumericCode(6);
    const codeHash = await bcrypt.hash(code, BCRYPT_ROUNDS);
    const expiresAt = new Date(Date.now() + ttlMs);

    const row = this.repo.create({
      recipient,
      recipientKind,
      channel: requestedChannel,
      codeHash,
      expiresAt,
      status: 'pending',
      consumedAt: null,
      attemptsCount: 0,
      sendCount: 1,
      createdIp: params.ip,
    });
    await this.repo.save(row);

    await this.delivery.deliver({
      code,
      ttlSeconds: Math.floor(ttlMs / 1000),
      recipient: recipientKind === 'email' ? recipient : `+${recipient}`,
      recipientKind,
      requestedChannel,
    });

    const base = {
      challenge_id: row.id,
      expires_in: Math.floor(ttlMs / 1000),
      resend_after: Math.floor(RESEND_COOLDOWN_MS / 1000),
    };
    if (process.env.NODE_ENV !== 'production') {
      const debugFlag = (this.config.get<string>('OTP_DEBUG_RETURN_CODE') || '').trim().toLowerCase();
      if (debugFlag === '1' || debugFlag === 'true' || debugFlag === 'yes') {
        return { ...base, debug_otp: code };
      }
    }
    return base;
  }

  async verifyChallenge(
    challengeId: string,
    code: string,
    expectedRecipient: string,
    expectedKind: OtpRecipientKind,
  ): Promise<AuthOtpChallenge> {
    const row = await this.repo.findOne({ where: { id: challengeId } });
    if (!row || row.recipient !== expectedRecipient || row.recipientKind !== expectedKind) {
      throw new BadRequestException('Неверный код или сессия подтверждения');
    }
    if (row.status === 'consumed') {
      throw new BadRequestException('Код уже использован. Запросите новый.');
    }
    if (row.status === 'locked') {
      throw new BadRequestException('Превышено число попыток. Запросите новый код.');
    }
    if (row.expiresAt.getTime() < Date.now()) {
      row.status = 'consumed';
      row.consumedAt = new Date();
      await this.repo.save(row);
      throw new BadRequestException('Срок действия кода истёк');
    }
    const maxAttempts = this.otpMaxAttempts();
    if (row.attemptsCount >= maxAttempts) {
      row.status = 'locked';
      await this.repo.save(row);
      throw new BadRequestException('Превышено число попыток. Запросите новый код.');
    }

    const ok = await bcrypt.compare(code.trim(), row.codeHash);
    if (!ok) {
      row.attemptsCount += 1;
      if (row.attemptsCount >= maxAttempts) {
        row.status = 'locked';
      }
      await this.repo.save(row);
      throw new BadRequestException('Неверный код');
    }

    row.status = 'consumed';
    row.consumedAt = new Date();
    await this.repo.save(row);
    return row;
  }
}
