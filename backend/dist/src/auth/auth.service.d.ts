import { Repository } from 'typeorm';
import { User, BusinessRole } from '../users/user.entity';
import { Organization } from '../organizations/organization.entity';
import { UsersService } from '../users/users.service';
import { AuthOtpService } from './auth-otp.service';
import { AuthSessionService, JwtAudience, SessionDeviceMeta } from './auth-session.service';
import { AuthSecurityEventService } from './auth-security-event.service';
export declare class AuthService {
    private userRepo;
    private orgRepo;
    private usersService;
    private otp;
    private sessions;
    private securityEvents;
    constructor(userRepo: Repository<User>, orgRepo: Repository<Organization>, usersService: UsersService, otp: AuthOtpService, sessions: AuthSessionService, securityEvents: AuthSecurityEventService);
    private getOrCreateTestOrg;
    sendCode(params: {
        email?: string;
        phone?: string;
        channel?: string;
        ip: string | null;
    }): Promise<{
        challenge_id: string;
        expires_in: number;
        resend_after: number;
    }>;
    private applyPhoneUnverified;
    verifyCode(dto: {
        email?: string;
        phone?: string;
        challenge_id: string;
        code: string;
        phone_unverified?: string;
        name?: string;
    }, audience: JwtAudience, meta: SessionDeviceMeta): Promise<{
        access_token: string;
        refresh_token: string;
        expires_in: number;
        session_id: string;
        user: {
            id: string;
            email: string | null;
            email_verified_at: string | null;
            phone: string | null;
            phone_verified_at: string | null;
            name: string;
            role: BusinessRole;
            organization_id: string | null;
            organizations: unknown[];
        };
    }>;
    refresh(refreshToken: string, audience: JwtAudience, meta: SessionDeviceMeta): Promise<{
        access_token: string;
        refresh_token: string;
        expires_in: number;
        session_id: string;
        user: {
            id: string;
            email: string | null;
            email_verified_at: string | null;
            phone: string | null;
            phone_verified_at: string | null;
            name: string;
            role: BusinessRole;
            organization_id: string | null;
            organizations: unknown[];
        };
    }>;
    logoutByRefresh(refreshToken: string): Promise<void>;
    logoutAllSessions(userId: string): Promise<number>;
}
