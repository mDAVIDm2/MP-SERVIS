"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const typeorm_1 = require("typeorm");
const path = require("path");
const root = path.join(__dirname, '..', '..');
exports.default = new typeorm_1.DataSource({
    type: 'postgres',
    url: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/autohub',
    entities: [path.join(root, 'src', '**', '*.entity{.ts,.js}')],
    migrations: [path.join(__dirname, 'migrations', '*.{ts,js}')],
    logging: process.env.NODE_ENV === 'development',
});
//# sourceMappingURL=data-source.js.map