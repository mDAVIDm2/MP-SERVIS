"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.typeOrmConfig = void 0;
const typeorm_1 = require("typeorm");
exports.typeOrmConfig = {
    type: 'postgres',
    url: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/autohub',
    entities: [__dirname + '/../**/*.entity{.ts,.js}'],
    synchronize: false,
    logging: process.env.NODE_ENV === 'development',
};
exports.default = new typeorm_1.DataSource({
    ...exports.typeOrmConfig,
    migrations: [__dirname + '/migrations/*{.ts,.js}'],
});
//# sourceMappingURL=typeorm.config.js.map