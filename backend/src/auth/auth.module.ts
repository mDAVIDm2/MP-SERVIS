import { Module } from '@nestjs/common';
import { ThrottlerModule } from '@nestjs/throttler';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { User } from '../users/user.entity';
import { Organization } from '../organizations/organization.entity';
import { UsersModule } from '../users/users.module';
import { OrganizationsModule } from '../organizations/organizations.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { AuthOtpChallenge } from './auth-otp-challenge.entity';
import { UserSession } from './user-session.entity';
import { SecurityEvent } from './security-event.entity';
import { AuthController } from './auth.controller';
import { AuthSessionsController } from './auth-sessions.controller';
import { AuthService } from './auth.service';
import { JwtStrategy } from './jwt.strategy';
import { AuthOtpService } from './auth-otp.service';
import { AuthSessionService } from './auth-session.service';
import { AuthSecurityEventService } from './auth-security-event.service';
import { ConsoleOtpDeliveryProvider } from './otp-delivery/console-otp-delivery.provider';
import { EmailOtpDeliveryProvider } from './otp-delivery/email-otp-delivery.provider';
import { SmsOtpDeliveryProvider } from './otp-delivery/sms-otp-delivery.provider';
import { OtpDeliveryAggregator } from './otp-delivery/otp-delivery.aggregator';

@Module({
  imports: [
    ThrottlerModule,
    TypeOrmModule.forFeature([User, Organization, AuthOtpChallenge, UserSession, SecurityEvent]),
    UsersModule,
    OrganizationsModule,
    NotificationsModule,
    PassportModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>('JWT_SECRET') || 'dev-secret',
        signOptions: {
          expiresIn:
            config.get<string>('JWT_ACCESS_EXPIRES_IN') || config.get<string>('JWT_EXPIRES_IN') || '15m',
        },
      }),
      inject: [ConfigService],
    }),
  ],
  controllers: [AuthController, AuthSessionsController],
  providers: [
    ConsoleOtpDeliveryProvider,
    EmailOtpDeliveryProvider,
    SmsOtpDeliveryProvider,
    OtpDeliveryAggregator,
    AuthOtpService,
    AuthSecurityEventService,
    AuthSessionService,
    AuthService,
    JwtStrategy,
  ],
  exports: [AuthService, JwtModule, AuthSessionService, AuthSecurityEventService],
})
export class AuthModule {}
