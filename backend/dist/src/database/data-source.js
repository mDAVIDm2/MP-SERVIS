"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const typeorm_1 = require("typeorm");
const path = require("path");
try {
    require('dotenv').config({ path: path.join(__dirname, '..', '..', '.env') });
}
catch {
}
const root = path.join(__dirname, '..', '..');
function posix(p) {
    return p.split(path.sep).join('/');
}
exports.default = new typeorm_1.DataSource({
    type: 'postgres',
    url: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/mp_servis',
    entities: [posix(path.join(root, 'src', '**', '*.entity{.ts,.js}'))],
    migrations: [posix(path.join(__dirname, 'migrations', '*.{ts,js}'))],
    logging: process.env.NODE_ENV === 'development',
});
//# sourceMappingURL=data-source.js.map