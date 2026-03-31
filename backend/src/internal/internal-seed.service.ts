import { Injectable, OnApplicationBootstrap } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { InternalOperator } from './internal-operator.entity';
import { InternalAuthService } from './internal-auth.service';

const ENV_INITIAL_EMAIL = 'INITIAL_SUPERADMIN_EMAIL';
const ENV_INITIAL_PASSWORD = 'INITIAL_SUPERADMIN_PASSWORD';

@Injectable()
export class InternalSeedService implements OnApplicationBootstrap {
  constructor(
    @InjectRepository(InternalOperator)
    private operatorRepo: Repository<InternalOperator>,
    private auth: InternalAuthService,
  ) {}

  async onApplicationBootstrap() {
    const email = process.env[ENV_INITIAL_EMAIL]?.trim();
    const password = process.env[ENV_INITIAL_PASSWORD]?.trim();
    if (!email || !password) {
      if (process.env.NODE_ENV !== 'production') {
        console.log(
          '[Internal] Seed skipped: set INITIAL_SUPERADMIN_EMAIL and INITIAL_SUPERADMIN_PASSWORD in .env to create/update superadmin',
        );
      }
      return;
    }

    const normalizedEmail = email.toLowerCase();
    const passwordHash = await this.auth.hashPassword(password);
    const existing = await this.operatorRepo.findOne({
      where: { email: normalizedEmail },
    });

    if (existing) {
      existing.passwordHash = passwordHash;
      existing.name = 'Суперадмин';
      existing.role = 'superadmin';
      existing.isActive = true;
      await this.operatorRepo.save(existing);
      if (process.env.NODE_ENV !== 'production') {
        console.log('[Internal] Updated initial superadmin from env:', normalizedEmail);
      }
      return;
    }

    const operator = this.operatorRepo.create({
      email: normalizedEmail,
      passwordHash,
      name: 'Суперадмин',
      role: 'superadmin',
      isActive: true,
    });
    await this.operatorRepo.save(operator);
    if (process.env.NODE_ENV !== 'production') {
      console.log('[Internal] Created initial superadmin from env:', normalizedEmail);
    }
  }
}
