import { JwtService } from '@nestjs/jwt';
import { Repository } from 'typeorm';
import { AuditLog } from '../audit/audit-log.entity';
import { InternalOperator } from './internal-operator.entity';
export interface InternalLoginResult {
    access_token: string;
    user: {
        id: string;
        email: string;
        name: string;
        role: string;
    };
}
export declare class InternalAuthService {
    private operatorRepo;
    private auditRepo;
    private jwtService;
    constructor(operatorRepo: Repository<InternalOperator>, auditRepo: Repository<AuditLog>, jwtService: JwtService);
    login(email: string, password: string): Promise<InternalLoginResult>;
    findById(id: string): Promise<InternalOperator | null>;
    hashPassword(password: string): Promise<string>;
}
