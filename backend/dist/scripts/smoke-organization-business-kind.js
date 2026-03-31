"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const organization_business_kind_1 = require("../src/organizations/organization-business-kind");
function assert(cond, msg) {
    if (!cond)
        throw new Error(msg);
}
assert((0, organization_business_kind_1.normalizeOrganizationBusinessKind)('car_wash') === 'car_wash', 'car_wash');
assert((0, organization_business_kind_1.normalizeOrganizationBusinessKind)('STO') === 'sto', 'sto case');
assert((0, organization_business_kind_1.normalizeOrganizationBusinessKind)('unknown-xyz') === 'sto', 'fallback sto');
assert(organization_business_kind_1.ORGANIZATION_BUSINESS_KINDS.includes('tire_service'), 'kinds seeded');
console.log('smoke-organization-business-kind: ok', organization_business_kind_1.ORGANIZATION_BUSINESS_KINDS.length);
//# sourceMappingURL=smoke-organization-business-kind.js.map