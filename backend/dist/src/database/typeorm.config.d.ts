import type { TypeOrmModuleOptions } from '@nestjs/typeorm';
import { DataSource, DataSourceOptions } from 'typeorm';
export declare function getTypeOrmModuleOptions(databaseUrl?: string): TypeOrmModuleOptions;
export declare const typeOrmDataSourceOptions: DataSourceOptions;
declare const _default: DataSource;
export default _default;
