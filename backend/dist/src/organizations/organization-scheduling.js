"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.defaultSchedulingModeForBusinessKind = defaultSchedulingModeForBusinessKind;
exports.normalizeSchedulingMode = normalizeSchedulingMode;
const organization_business_kind_1 = require("./organization-business-kind");
const DEFAULT_BAY_BUSINESS_KINDS = new Set([
    'car_wash',
    'tire_service',
    'detailing',
    'body_shop',
]);
function defaultSchedulingModeForBusinessKind(kind) {
    const k = (0, organization_business_kind_1.normalizeOrganizationBusinessKind)(kind);
    return DEFAULT_BAY_BUSINESS_KINDS.has(k) ? 'bay_based' : 'staff_based';
}
function normalizeSchedulingMode(v) {
    const s = String(v ?? 'staff_based').trim().toLowerCase();
    return s === 'bay_based' ? 'bay_based' : 'staff_based';
}
//# sourceMappingURL=organization-scheduling.js.map