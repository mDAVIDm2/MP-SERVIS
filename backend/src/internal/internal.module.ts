import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ThrottlerModule } from '@nestjs/throttler';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuditLog } from '../audit/audit-log.entity';
import { InternalOperator } from './internal-operator.entity';
import { InternalAuthService } from './internal-auth.service';
import { InternalAuthController } from './internal-auth.controller';
import { InternalJwtStrategy } from './internal-jwt.strategy';
import { InternalSeedService } from './internal-seed.service';
import { InternalOrganizationsController } from './internal-organizations.controller';
import { InternalUsersController } from './internal-users.controller';
import { InternalOrdersController } from './internal-orders.controller';
import { InternalReferenceController } from './internal-reference.controller';
import { InternalAuditController } from './internal-audit.controller';
import { InternalAuditService } from './internal-audit.service';
import { InternalSubscriptionsController } from './internal-subscriptions.controller';
import { InternalServiceDictionariesController } from './internal-service-dictionaries.controller';
import { InternalServiceCatalogSuggestionsController } from './internal-service-catalog-suggestions.controller';
import { OrganizationsModule } from '../organizations/organizations.module';
import { UsersModule } from '../users/users.module';
import { OrdersModule } from '../orders/orders.module';
import { ReferenceModule } from '../reference/reference.module';
import { ChatsModule } from '../chats/chats.module';
import { InternalClientCarsController } from './internal-client-cars.controller';
import { InternalSupportChatsController } from './internal-support-chats.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([InternalOperator, AuditLog]),
    PassportModule,
    ThrottlerModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      useFactory: (config: ConfigService) => {
        const secret = config.get<string>('INTERNAL_JWT_SECRET')?.trim();
        if (process.env.NODE_ENV === 'production' && !secret) {
          throw new Error('INTERNAL_JWT_SECRET is required when NODE_ENV=production');
        }
        return {
          secret: secret || 'dev-internal-secret',
          signOptions: { expiresIn: config.get<string>('JWT_EXPIRES_IN') || '7d' },
        };
      },
      inject: [ConfigService],
    }),
    OrganizationsModule,
    UsersModule,
    OrdersModule,
    ReferenceModule,
    ChatsModule,
  ],
  controllers: [
    InternalAuthController,
    InternalOrganizationsController,
    InternalUsersController,
    InternalOrdersController,
    InternalClientCarsController,
    InternalSupportChatsController,
    InternalReferenceController,
    InternalAuditController,
    InternalSubscriptionsController,
    InternalServiceDictionariesController,
    InternalServiceCatalogSuggestionsController,
  ],
  providers: [InternalAuthService, InternalJwtStrategy, InternalSeedService, InternalAuditService],
  exports: [InternalAuthService],
})
export class InternalModule {}
