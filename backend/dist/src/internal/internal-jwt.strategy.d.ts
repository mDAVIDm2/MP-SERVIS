import { ConfigService } from '@nestjs/config';
import { Strategy } from 'passport-jwt';
import { InternalAuthService } from './internal-auth.service';
interface JwtPayload {
    sub: string;
    scope?: string;
    internal_role?: string;
}
declare const InternalJwtStrategy_base: new (...args: any[]) => Strategy;
export declare class InternalJwtStrategy extends InternalJwtStrategy_base {
    private auth;
    constructor(auth: InternalAuthService, config: ConfigService);
    validate(payload: JwtPayload): Promise<import("./internal-operator.entity").InternalOperator>;
}
export {};
