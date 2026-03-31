import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { AuditLog } from '../audit/audit-log.entity';
import { InternalOperator } from './internal-operator.entity';

const SALT_ROUNDS = 10;

export interface InternalLoginResult {
  access_token: string;
  user: {
    id: string;
    email: string;
    name: string;
    role: string;
  };
}

@Injectable()
export class InternalAuthService {
  constructor(
    @InjectRepository(InternalOperator)
    private operatorRepo: Repository<InternalOperator>,
    @InjectRepository(AuditLog) private auditRepo: Repository<AuditLog>,
    private jwtService: JwtService,
  ) {}

  async login(email: string, password: string): Promise<InternalLoginResult> {
    const normalizedEmail = email.trim().toLowerCase();
    const operator = await this.operatorRepo.findOne({
      where: { email: normalizedEmail, isActive: true },
    });
    if (!operator) {
      if (process.env.NODE_ENV !== 'production') {
        console.log('[Internal] Login failed: operator not found for email:', normalizedEmail);
      }
      throw new UnauthorizedException('Неверный email или пароль');
    }
    const valid = await bcrypt.compare(password, operator.passwordHash);
    if (!valid) {
      if (process.env.NODE_ENV !== 'production') {
        console.log('[Internal] Login failed: invalid password for email:', normalizedEmail);
      }
      throw new UnauthorizedException('Неверный email или пароль');
    }
    const payload = {
      sub: operator.id,
      email: operator.email,
      scope: 'internal',
      internal_role: operator.role,
    };
    const access_token = this.jwtService.sign(payload);
    const actorName = operator.name || operator.email;
    this.auditRepo
      .save(
        this.auditRepo.create({
          actorId: operator.id,
          actorType: 'internal',
          actorName,
          action: 'login',
          resourceType: null,
          resourceId: null,
          details: { email: operator.email },
        }),
      )
      .catch(() => {});
    return {
      access_token,
      user: {
        id: operator.id,
        email: operator.email,
        name: operator.name || operator.email.split('@')[0],
        role: operator.role,
      },
    };
  }

  async findById(id: string): Promise<InternalOperator | null> {
    return this.operatorRepo.findOne({ where: { id, isActive: true } });
  }

  async hashPassword(password: string): Promise<string> {
    return bcrypt.hash(password, SALT_ROUNDS);
  }
}
