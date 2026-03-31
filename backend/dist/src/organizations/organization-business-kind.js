"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ORGANIZATION_BUSINESS_KINDS = void 0;
exports.normalizeOrganizationBusinessKind = normalizeOrganizationBusinessKind;
exports.ORGANIZATION_BUSINESS_KINDS = [
    'sto',
    'car_wash',
    'detailing',
    'car_audio',
    'tire_service',
    'body_shop',
    'glass',
    'tuning',
    'ev_service',
    'other',
];
function normalizeOrganizationBusinessKind(v) {
    const s = String(v ?? 'sto')
        .trim()
        .toLowerCase()
        .replace(/-/g, '_');
    return exports.ORGANIZATION_BUSINESS_KINDS.includes(s)
        ? s
        : 'sto';
}
//# sourceMappingURL=organization-business-kind.js.map