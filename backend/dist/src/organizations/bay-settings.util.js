"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.normalizeOrgBays = normalizeOrgBays;
exports.effectiveBayCountFromSlots = effectiveBayCountFromSlots;
exports.bayNameMapFromSlots = bayNameMapFromSlots;
function normalizeOrgBays(slots) {
    if (slots === null || typeof slots !== 'object')
        return [];
    const bays = slots.bays;
    if (!Array.isArray(bays))
        return [];
    const out = [];
    for (const b of bays) {
        if (b === null || typeof b !== 'object')
            continue;
        const id = String(b.id ?? '').trim();
        const name = String(b.name ?? '').trim() || 'Пост';
        if (id.length > 0)
            out.push({ id, name });
    }
    return out;
}
function effectiveBayCountFromSlots(slots) {
    const named = normalizeOrgBays(slots);
    if (named.length > 0)
        return Math.min(20, named.length);
    if (slots === null || typeof slots !== 'object')
        return 3;
    const n = Number(slots.bay_count);
    return Math.max(1, Math.min(20, Number.isFinite(n) && n > 0 ? n : 3));
}
function bayNameMapFromSlots(slots) {
    const m = new Map();
    for (const b of normalizeOrgBays(slots)) {
        m.set(b.id, b.name);
    }
    return m;
}
//# sourceMappingURL=bay-settings.util.js.map