import { ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import { UsersService } from '../users/users.service';
import { OrganizationsService } from '../organizations/organizations.service';
import { UserSession } from './user-session.entity';

export const SUBSCRIPTION_DEACTIVATED_CODE = 'subscription_deactivated';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    private users: UsersService,
    private org: OrganizationsService,
    config: ConfigService,
    @InjectRepository(UserSession) private sessionRepo: Repository<UserSession>,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: (() => {
        const secret = config.get<string>('JWT_SECRET')?.trim();
        if (process.env.NODE_ENV === 'production' && !secret) {
          throw new Error('JWT_SECRET is required when NODE_ENV=production');
        }
        return secret || 'dev-secret';
      })(),
    });
  }

  async validate(payload: { sub: string; sid?: string; aud?: string }) {
    const user = await this.users.findById(payload.sub);
    if (!user) return null;

    if (payload.sid) {
      const s = await this.sessionRepo.findOne({
        where: { id: payload.sid, userId: user.id, revokedAt: IsNull() },
      });
      if (!s) {
        throw new UnauthorizedException({
          code: 'session_revoked',
          message: 'Сессия завершена. Войдите снова.',
        });
      }
    }

    if (user.organizationId) {
      const active = await this.org.isSubscriptionActive(user.organizationId);
      if (!active) {
        throw new ForbiddenException({
          code: SUBSCRIPTION_DEACTIVATED_CODE,
          message: 'Подписка деактивирована. Обратитесь к администратору.',
        });
      }
    }
    return user;
  }
}
