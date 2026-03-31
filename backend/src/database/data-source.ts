import { DataSource } from 'typeorm';
import * as path from 'path';

const root = path.join(__dirname, '..', '..');

export default new DataSource({
  type: 'postgres',
  url: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/autohub',
  entities: [path.join(root, 'src', '**', '*.entity{.ts,.js}')],
  migrations: [path.join(__dirname, 'migrations', '*.{ts,js}')],
  logging: process.env.NODE_ENV === 'development',
});
