import { InternalAuthService, InternalLoginResult } from './internal-auth.service';
import { InternalOperator } from './internal-operator.entity';
import { InternalLoginDto } from './dto/internal-login.dto';
export declare class InternalAuthController {
    private auth;
    constructor(auth: InternalAuthService);
    login(body: InternalLoginDto): Promise<InternalLoginResult>;
    me(operator: InternalOperator): Promise<{
        id: string;
        email: string;
        name: string;
        role: string;
    }>;
}
