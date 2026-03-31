import { BadRequestException, Body, Controller, Ip, Post, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { Request } from 'express';
import { Throttle, ThrottlerGuard } from '@nestjs/throttler';
import { AuthService } from './auth.service';
import { SendCodeDto, VerifyCodeDto, RefreshDto, LogoutDto } from './dto/auth.dto';
import { JwtAudience, SessionDeviceMeta } from './auth-session.service';
import { User } from '../users/user.entity';

function audienceFromReq(req: Request): JwtAudience {
  const raw = String(req.headers['x-autohub-app'] ?? '').toLowerCase();
  return raw === 'business' ? 'business' : 'client';
}

function deviceMeta(
  req: Request,
  body: { device_id?: string; device_name?: string; platform?: string },
): SessionDeviceMeta {
  const ua = req.headers['user-agent'];
  return {
    deviceId: body.device_id ?? null,
    deviceName: body.device_name ?? null,
    platform: body.platform ?? null,
    userAgent: typeof ua === 'string' ? ua.slice(0, 512) : null,
    ip: req.ip || null,
  };
}

@Controller('auth')
@UseGuards(ThrottlerGuard)
@Throttle({ default: { limit: 60, ttl: 60000 } })
export class AuthController {
  constructor(private auth: AuthService) {}

  @Post('send-code')
  @Throttle({ default: { limit: 12, ttl: 60000 } })
  async sendCode(@Body() dto: SendCodeDto, @Req() req: Request, @Ip() ip: string) {
    if (
      (dto.email == null || String(dto.email).trim() === '') &&
      (dto.phone == null || String(dto.phone).trim() === '')
    ) {
      throw new BadRequestException('Укажите email или phone');
    }
    if (
      dto.email != null &&
      String(dto.email).trim() !== '' &&
      dto.phone != null &&
      String(dto.phone).trim() !== ''
    ) {
      throw new BadRequestException('Укажите только email или только phone');
    }
    return this.auth.sendCode({
      email: dto.email,
      phone: dto.phone,
      channel: dto.channel,
      ip: ip || null,
    });
  }

  @Post('verify-code')
  @Throttle({ default: { limit: 30, ttl: 60000 } })
  async verifyCode(@Body() dto: VerifyCodeDto, @Req() req: Request) {
    const hasE = dto.email != null && String(dto.email).trim() !== '';
    const hasP = dto.phone != null && String(dto.phone).trim() !== '';
    if (!hasE && !hasP) throw new BadRequestException('Укажите email или phone');
    if (hasE && hasP) throw new BadRequestException('Укажите только email или только phone');
    const aud = audienceFromReq(req);
    return this.auth.verifyCode(
      {
        email: dto.email,
        phone: dto.phone,
        challenge_id: dto.challenge_id,
        code: dto.code,
        phone_unverified: dto.phone_unverified,
        name: dto.name,
      },
      aud,
      deviceMeta(req, dto),
    );
  }

  @Post('refresh')
  @Throttle({ default: { limit: 45, ttl: 60000 } })
  async refresh(@Body() dto: RefreshDto, @Req() req: Request) {
    const aud = audienceFromReq(req);
    return this.auth.refresh(dto.refresh_token, aud, deviceMeta(req, dto));
  }

  @Post('logout')
  @Throttle({ default: { limit: 20, ttl: 60000 } })
  async logout(@Body() dto: LogoutDto) {
    await this.auth.logoutByRefresh(dto.refresh_token);
    return { ok: true };
  }

  /** Завершить все сессии пользователя (включая текущую). Access JWT истечёт по TTL. */
  @Post('logout-all')
  @UseGuards(AuthGuard('jwt'))
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  async logoutAll(@Req() req: Request & { user: User }) {
    const n = await this.auth.logoutAllSessions(req.user.id);
    return { ok: true, revoked: n };
  }
}
