import { MigrationInterface, QueryRunner } from 'typeorm';
export declare class SmartScheduling1730300000000 implements MigrationInterface {
    name: string;
    up(queryRunner: QueryRunner): Promise<void>;
    down(queryRunner: QueryRunner): Promise<void>;
}
