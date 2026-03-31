import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { InternalAuthService } from './internal-auth.service';

interface JwtPayload {
  sub: string;
  scope?: string;
  internal_role?: string;
}

@Injectable()
export class InternalJwtStrategy extends PassportStrategy(Strategy, 'internal-jwt') {
  constructor(
    private auth: InternalAuthService,
    config: ConfigService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.get<string>('JWT_SECRET') || 'dev-secret',
    });
  }

  async validate(payload: JwtPayload) {
    if (payload.scope !== 'internal') {
      throw new UnauthorizedException('Invalid token scope');
    }
    const operator = await this.auth.findById(payload.sub);
    if (!operator) throw new UnauthorizedException('Operator not found');
    return operator;
  }
}
