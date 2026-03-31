import { DataSource, DataSourceOptions } from 'typeorm';

export const typeOrmConfig: DataSourceOptions = {
  type: 'postgres',
  url: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/autohub',
  entities: [__dirname + '/../**/*.entity{.ts,.js}'],
  synchronize: false, // всегда использовать миграции (synchronize при наличии NULL в email ломает старт)
  logging: process.env.NODE_ENV === 'development',
};

export default new DataSource({
  ...typeOrmConfig,
  migrations: [__dirname + '/migrations/*{.ts,.js}'],
});
