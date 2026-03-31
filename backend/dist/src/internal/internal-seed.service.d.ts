import { OnApplicationBootstrap } from '@nestjs/common';
import { Repository } from 'typeorm';
import { InternalOperator } from './internal-operator.entity';
import { InternalAuthService } from './internal-auth.service';
export declare class InternalSeedService implements OnApplicationBootstrap {
    private operatorRepo;
    private auth;
    constructor(operatorRepo: Repository<InternalOperator>, auth: InternalAuthService);
    onApplicationBootstrap(): Promise<void>;
}
