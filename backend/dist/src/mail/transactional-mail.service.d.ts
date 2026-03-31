import { ConfigService } from '@nestjs/config';
export declare class TransactionalMailService {
    private readonly config;
    private readonly log;
    constructor(config: ConfigService);
    private resolveFromAddress;
    isConfigured(): boolean;
    send(params: {
        to: string;
        subject: string;
        text: string;
        html?: string;
    }): Promise<void>;
    private sendViaResend;
}
