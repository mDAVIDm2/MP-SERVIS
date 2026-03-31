import {
  Controller,
  Delete,
  Get,
  NotFoundException,
  Param,
  ParseUUIDPipe,
  Post,
  Req,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { JwtService } from '@nestjs/jwt';
import { Request } from 'express';
import { ExtractJwt } from 'passport-jwt';
import { User } from '../users/user.entity';
import { AuthSessionService } from './auth-session.service';
import { AuthSecurityEventService } from './auth-security-event.service';
import { Throttle, ThrottlerGuard } from '@nestjs/throttler';

@Controller('auth')
@UseGuards(AuthGuard('jwt'), ThrottlerGuard)
@Throttle({ default: { limit: 120, ttl: 60000 } })
export class AuthSessionsController {
  constructor(
    private readonly sessions: AuthSessionService,
    private readonly securityEvents: AuthSecurityEventService,
    private readonly jwt: JwtService,
  ) {}

  private currentSessionId(req: Request): string | null {
    const extractor = ExtractJwt.fromAuthHeaderAsBearerToken();
    const token = extractor(req);
    if (!token) return null;
    try {
      const p = this.jwt.decode(token) as { sid?: string } | null;
      return p?.sid ?? null;
    } catch {
      return null;
    }
  }

  @Get('sessions')
  async listSessions(@Req() req: Request & { user: User }) {
    const sid = this.currentSessionId(req);
    return { items: await this.sessions.listSessions(req.user.id, sid) };
  }

  @Get('security-events')
  async listSecurityEvents(@Req() req: Request & { user: User }) {
    return { items: await this.securityEvents.listForUser(req.user.id) };
  }

  @Delete('sessions/:id')
  async revokeSession(@Req() req: Request & { user: User }, @Param('id', ParseUUIDPipe) id: string) {
    const sid = this.currentSessionId(req);
    if (id === sid) {
      throw new UnauthorizedException('Используйте «Выйти» для текущего устройства');
    }
    const ok = await this.sessions.revokeSession(req.user.id, id);
    if (!ok) throw new NotFoundException('Сессия не найдена');
    return { ok: true };
  }

  @Post('sessions/revoke-others')
  async revokeOthers(@Req() req: Request & { user: User }) {
    const sid = this.currentSessionId(req);
    if (!sid) throw new UnauthorizedException('Нет активной сессии в токене');
    const n = await this.sessions.revokeAllExcept(req.user.id, sid);
    return { ok: true, revoked: n };
  }
}
