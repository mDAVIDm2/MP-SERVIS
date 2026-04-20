import { Request } from 'express';
import { AuthService } from './auth.service';
import { SendCodeDto, VerifyCodeDto, RefreshDto, LogoutDto } from './dto/auth.dto';
import { User } from '../users/user.entity';
export declare class AuthController {
    private auth;
    constructor(auth: AuthService);
    sendCode(dto: SendCodeDto, req: Request, ip: string): Promise<{
        account_exists: boolean;
        challenge_id: string;
        expires_in: number;
        resend_after: number;
        debug_otp?: string;
    }>;
    verifyCode(dto: VerifyCodeDto, req: Request): Promise<{
        access_token: string;
        refresh_token: string;
        expires_in: number;
        session_id: string;
        user: Record<string, unknown>;
    }>;
    refresh(dto: RefreshDto, req: Request): Promise<{
        access_token: string;
        refresh_token: string;
        expires_in: number;
        session_id: string;
        user: Record<string, unknown>;
    }>;
    logout(dto: LogoutDto): Promise<{
        ok: boolean;
    }>;
    logoutAll(req: Request & {
        user: User;
    }): Promise<{
        ok: boolean;
        revoked: number;
    }>;
}
