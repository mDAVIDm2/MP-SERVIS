"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SUBSCRIPTION_PLANS = exports.SUBSCRIPTION_PLAN_KEYS = void 0;
exports.normalizePlanKey = normalizePlanKey;
exports.getPlanLimits = getPlanLimits;
exports.sanitizeLimitOverrideValue = sanitizeLimitOverrideValue;
exports.mergePlanLimitsWithOverride = mergePlanLimitsWithOverride;
exports.listPublicSubscriptionPlans = listPublicSubscriptionPlans;
exports.SUBSCRIPTION_PLAN_KEYS = ['solo', 'team', 'business', 'pro', 'network'];
exports.SUBSCRIPTION_PLANS = {
    solo: {
        maxActiveStaff: 0,
        maxConfirmedOrdersPerMonth: 50,
        maxOrderMediaAttachments: 2,
        maxChatImagesPerMessage: 2,
    },
    team: {
        maxActiveStaff: 4,
        maxConfirmedOrdersPerMonth: 150,
        maxOrderMediaAttachments: 10,
        maxChatImagesPerMessage: 4,
    },
    business: {
        maxActiveStaff: 8,
        maxConfirmedOrdersPerMonth: 300,
        maxOrderMediaAttachments: 16,
        maxChatImagesPerMessage: 6,
    },
    pro: {
        maxActiveStaff: 20,
        maxConfirmedOrdersPerMonth: 1000,
        maxOrderMediaAttachments: 40,
        maxChatImagesPerMessage: 10,
    },
    network: {
        maxActiveStaff: null,
        maxConfirmedOrdersPerMonth: null,
        maxOrderMediaAttachments: null,
        maxChatImagesPerMessage: null,
    },
};
function normalizePlanKey(raw) {
    const k = String(raw || 'team').toLowerCase().trim();
    if (exports.SUBSCRIPTION_PLAN_KEYS.includes(k))
        return k;
    return 'team';
}
function getPlanLimits(key) {
    return exports.SUBSCRIPTION_PLANS[key] ?? exports.SUBSCRIPTION_PLANS.team;
}
function sanitizeLimitOverrideValue(v) {
    if (v === undefined)
        return undefined;
    if (v === null)
        return null;
    if (typeof v === 'number' && Number.isFinite(v) && v >= 0) {
        return Math.min(Math.floor(v), 1_000_000_000);
    }
    if (typeof v === 'string') {
        const t = v.trim().toLowerCase();
        if (t === '' || t === 'unlimited' || t === 'безлимит' || t === 'none')
            return null;
        const n = parseInt(t, 10);
        if (!Number.isNaN(n) && n >= 0)
            return Math.min(n, 1_000_000_000);
    }
    return undefined;
}
function mergePlanLimitsWithOverride(base, override) {
    if (!override || typeof override !== 'object' || Array.isArray(override)) {
        return { ...base };
    }
    const o = override;
    const getVal = (...keys) => {
        for (const k of keys) {
            if (Object.prototype.hasOwnProperty.call(o, k))
                return o[k];
        }
        return undefined;
    };
    const mergeKey = (camel, ...snakeAliases) => {
        const raw = getVal(camel, ...snakeAliases);
        if (raw === undefined)
            return base[camel];
        const s = sanitizeLimitOverrideValue(raw);
        if (s === undefined)
            return base[camel];
        return s;
    };
    return {
        maxActiveStaff: mergeKey('maxActiveStaff', 'max_active_staff'),
        maxConfirmedOrdersPerMonth: mergeKey('maxConfirmedOrdersPerMonth', 'max_confirmed_orders_per_month'),
        maxOrderMediaAttachments: mergeKey('maxOrderMediaAttachments', 'max_order_media_attachments'),
        maxChatImagesPerMessage: mergeKey('maxChatImagesPerMessage', 'max_chat_images_per_message'),
    };
}
function listPublicSubscriptionPlans() {
    return exports.SUBSCRIPTION_PLAN_KEYS.map((plan_key) => ({
        plan_key,
        limits: { ...exports.SUBSCRIPTION_PLANS[plan_key] },
    }));
}
//# sourceMappingURL=plan-definitions.js.map