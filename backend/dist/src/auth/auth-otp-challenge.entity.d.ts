export type OtpRecipientKind = 'email' | 'phone';
export type OtpChallengeStatus = 'pending' | 'consumed' | 'locked';
export declare class AuthOtpChallenge {
    id: string;
    recipient: string;
    recipientKind: OtpRecipientKind;
    channel: string;
    codeHash: string;
    expiresAt: Date;
    status: OtpChallengeStatus;
    consumedAt: Date | null;
    attemptsCount: number;
    sendCount: number;
    createdAt: Date;
    createdIp: string | null;
}
