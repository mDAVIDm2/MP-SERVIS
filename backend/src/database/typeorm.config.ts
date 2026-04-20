import { join } from 'path';
import type { TypeOrmModuleOptions } from '@nestjs/typeorm';
import { DataSource, DataSourceOptions } from 'typeorm';

/** Паттерн сущностей: на Windows glob с обратными слэшами не срабатывает. */
function entitiesGlob(): string {
  return join(__dirname, '..', '**', '*.entity{.ts,.js}').replace(/\\/g, '/');
}

const defaultDatabaseUrl = 'postgresql://postgres:postgres@localhost:5432/mp_servis';

export function getTypeOrmModuleOptions(databaseUrl?: string): TypeOrmModuleOptions {
  return {
    type: 'postgres',
    url: databaseUrl?.trim() || process.env.DATABASE_URL || defaultDatabaseUrl,
    entities: [entitiesGlob()],
    synchronize: false, // всегда использовать миграции (synchronize при наличии NULL в email ломает старт)
    logging: process.env.NODE_ENV === 'development',
  };
}

/** Для TypeORM CLI (миграции): URL из окружения на момент вызова. */
export const typeOrmDataSourceOptions: DataSourceOptions = {
  type: 'postgres',
  url: process.env.DATABASE_URL || defaultDatabaseUrl,
  entities: [entitiesGlob()],
  synchronize: false,
  logging: process.env.NODE_ENV === 'development',
};

export default new DataSource({
  ...typeOrmDataSourceOptions,
  migrations: [join(__dirname, 'migrations', '*.{ts,js}').replace(/\\/g, '/')],
});
