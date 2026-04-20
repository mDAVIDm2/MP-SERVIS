import { ConfigService } from '@nestjs/config';
import { Repository } from 'typeorm';
import { AuthOtpChallenge, OtpRecipientKind } from './auth-otp-challenge.entity';
import { OtpDeliveryAggregator } from './otp-delivery/otp-delivery.aggregator';
export interface CreateOtpParams {
    email?: string;
    phone?: string;
    requestedChannel?: string;
    ip: string | null;
}
export declare class AuthOtpService {
    private readonly repo;
    private readonly delivery;
    private readonly config;
    constructor(repo: Repository<AuthOtpChallenge>, delivery: OtpDeliveryAggregator, config: ConfigService);
    private otpTtlMs;
    private otpMaxAttempts;
    normalizeEmail(email: string): string;
    normalizePhoneDigits(phone: string): string;
    private resolveRecipient;
    private generateNumericCode;
    createChallenge(params: CreateOtpParams): Promise<{
        challenge_id: string;
        expires_in: number;
        resend_after: number;
        debug_otp?: string;
    }>;
    verifyChallenge(challengeId: string, code: string, expectedRecipient: string, expectedKind: OtpRecipientKind): Promise<AuthOtpChallenge>;
}
