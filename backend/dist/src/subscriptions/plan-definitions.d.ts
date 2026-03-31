export type SubscriptionPlanKey = 'solo' | 'team' | 'business' | 'pro' | 'network';
export interface SubscriptionPlanLimits {
    maxActiveStaff: number | null;
    maxConfirmedOrdersPerMonth: number | null;
    maxOrderMediaAttachments: number | null;
    maxChatImagesPerMessage: number | null;
}
export declare const SUBSCRIPTION_PLAN_KEYS: SubscriptionPlanKey[];
export declare const SUBSCRIPTION_PLANS: Record<SubscriptionPlanKey, SubscriptionPlanLimits>;
export declare function normalizePlanKey(raw: string | null | undefined): SubscriptionPlanKey;
export declare function getPlanLimits(key: SubscriptionPlanKey): SubscriptionPlanLimits;
export declare function sanitizeLimitOverrideValue(v: unknown): number | null | undefined;
export declare function mergePlanLimitsWithOverride(base: SubscriptionPlanLimits, override: Record<string, unknown> | null | undefined): SubscriptionPlanLimits;
export declare function listPublicSubscriptionPlans(): Array<{
    plan_key: SubscriptionPlanKey;
    limits: SubscriptionPlanLimits;
}>;
