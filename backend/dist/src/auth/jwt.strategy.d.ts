import { ConfigService } from '@nestjs/config';
import { Strategy } from 'passport-jwt';
import { Repository } from 'typeorm';
import { UsersService } from '../users/users.service';
import { OrganizationsService } from '../organizations/organizations.service';
import { UserSession } from './user-session.entity';
export declare const SUBSCRIPTION_DEACTIVATED_CODE = "subscription_deactivated";
declare const JwtStrategy_base: new (...args: any[]) => Strategy;
export declare class JwtStrategy extends JwtStrategy_base {
    private users;
    private org;
    private sessionRepo;
    constructor(users: UsersService, org: OrganizationsService, config: ConfigService, sessionRepo: Repository<UserSession>);
    validate(payload: {
        sub: string;
        sid?: string;
        aud?: string;
    }): Promise<import("../users/user.entity").User | null>;
}
export {};
