"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.typeOrmDataSourceOptions = void 0;
exports.getTypeOrmModuleOptions = getTypeOrmModuleOptions;
const path_1 = require("path");
const typeorm_1 = require("typeorm");
function entitiesGlob() {
    return (0, path_1.join)(__dirname, '..', '**', '*.entity{.ts,.js}').replace(/\\/g, '/');
}
const defaultDatabaseUrl = 'postgresql://postgres:postgres@localhost:5432/mp_servis';
function getTypeOrmModuleOptions(databaseUrl) {
    return {
        type: 'postgres',
        url: databaseUrl?.trim() || process.env.DATABASE_URL || defaultDatabaseUrl,
        entities: [entitiesGlob()],
        synchronize: false,
        logging: process.env.NODE_ENV === 'development',
    };
}
exports.typeOrmDataSourceOptions = {
    type: 'postgres',
    url: process.env.DATABASE_URL || defaultDatabaseUrl,
    entities: [entitiesGlob()],
    synchronize: false,
    logging: process.env.NODE_ENV === 'development',
};
exports.default = new typeorm_1.DataSource({
    ...exports.typeOrmDataSourceOptions,
    migrations: [(0, path_1.join)(__dirname, 'migrations', '*.{ts,js}').replace(/\\/g, '/')],
});
//# sourceMappingURL=typeorm.config.js.map