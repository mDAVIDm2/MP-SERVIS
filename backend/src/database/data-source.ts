import { DataSource } from 'typeorm';
import * as path from 'path';

try {
  require('dotenv').config({ path: path.join(__dirname, '..', '..', '.env') });
} catch {
  /* optional */
}

const root = path.join(__dirname, '..', '..');

function posix(p: string): string {
  return p.split(path.sep).join('/');
}

export default new DataSource({
  type: 'postgres',
  url: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/mp_servis',
  entities: [posix(path.join(root, 'src', '**', '*.entity{.ts,.js}'))],
  migrations: [posix(path.join(__dirname, 'migrations', '*.{ts,js}'))],
  logging: process.env.NODE_ENV === 'development',
});
