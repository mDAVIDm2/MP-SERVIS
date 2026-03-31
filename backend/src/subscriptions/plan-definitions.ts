/**
 * Единый конфиг тарифов (квоты и флаги).
 * Позже можно вынести в БД; сейчас — источник правды в коде.
 */
export type SubscriptionPlanKey = 'solo' | 'team' | 'business' | 'pro' | 'network';

export interface SubscriptionPlanLimits {
  /** Максимум активных сотрудников (staff_members.is_active). Solo = 0. null = без лимита. */
  maxActiveStaff: number | null;
  /** Макс. заказов с first_confirmed_at в биллинговом месяце организации. null = без лимита. */
  maxConfirmedOrdersPerMonth: number | null;
  /**
   * Макс. вложений (фото/будущие видео) на один заказ. Учитываются и legacy order_photos, и order_media.
   * null — без лимита.
   */
  maxOrderMediaAttachments: number | null;
  /** Макс. изображений в одном сообщении чата (организационные чаты). null — без лимита. Чат поддержки — без проверки тарифа. */
  maxChatImagesPerMessage: number | null;
}

export const SUBSCRIPTION_PLAN_KEYS: SubscriptionPlanKey[] = ['solo', 'team', 'business', 'pro', 'network'];

export const SUBSCRIPTION_PLANS: Record<SubscriptionPlanKey, SubscriptionPlanLimits> = {
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

export function normalizePlanKey(raw: string | null | undefined): SubscriptionPlanKey {
  const k = String(raw || 'team').toLowerCase().trim();
  if (SUBSCRIPTION_PLAN_KEYS.includes(k as SubscriptionPlanKey)) return k as SubscriptionPlanKey;
  return 'team';
}

export function getPlanLimits(key: SubscriptionPlanKey): SubscriptionPlanLimits {
  return SUBSCRIPTION_PLANS[key] ?? SUBSCRIPTION_PLANS.team;
}

/** Нормализация значения лимита: null = безлимит; число ≥ 0; иначе undefined (поле игнорировать). */
export function sanitizeLimitOverrideValue(v: unknown): number | null | undefined {
  if (v === undefined) return undefined;
  if (v === null) return null;
  if (typeof v === 'number' && Number.isFinite(v) && v >= 0) {
    return Math.min(Math.floor(v), 1_000_000_000);
  }
  if (typeof v === 'string') {
    const t = v.trim().toLowerCase();
    if (t === '' || t === 'unlimited' || t === 'безлимит' || t === 'none') return null;
    const n = parseInt(t, 10);
    if (!Number.isNaN(n) && n >= 0) return Math.min(n, 1_000_000_000);
  }
  return undefined;
}

/**
 * Слияние базовых лимитов тарифа с переопределением из БД (частичное).
 * Ключи в override: camelCase или snake_case (как из JSON API).
 */
export function mergePlanLimitsWithOverride(
  base: SubscriptionPlanLimits,
  override: Record<string, unknown> | null | undefined,
): SubscriptionPlanLimits {
  if (!override || typeof override !== 'object' || Array.isArray(override)) {
    return { ...base };
  }
  const o = override as Record<string, unknown>;
  const getVal = (...keys: string[]): unknown => {
    for (const k of keys) {
      if (Object.prototype.hasOwnProperty.call(o, k)) return o[k];
    }
    return undefined;
  };
  const mergeKey = (camel: keyof SubscriptionPlanLimits, ...snakeAliases: string[]): number | null => {
    const raw = getVal(camel, ...snakeAliases);
    if (raw === undefined) return base[camel];
    const s = sanitizeLimitOverrideValue(raw);
    if (s === undefined) return base[camel];
    return s;
  };
  return {
    maxActiveStaff: mergeKey('maxActiveStaff', 'max_active_staff'),
    maxConfirmedOrdersPerMonth: mergeKey('maxConfirmedOrdersPerMonth', 'max_confirmed_orders_per_month'),
    maxOrderMediaAttachments: mergeKey('maxOrderMediaAttachments', 'max_order_media_attachments'),
    maxChatImagesPerMessage: mergeKey('maxChatImagesPerMessage', 'max_chat_images_per_message'),
  };
}

/** Для UI: список тарифов и лимитов (создание организации, смена плана). */
export function listPublicSubscriptionPlans(): Array<{
  plan_key: SubscriptionPlanKey;
  limits: SubscriptionPlanLimits;
}> {
  return SUBSCRIPTION_PLAN_KEYS.map((plan_key) => ({
    plan_key,
    limits: { ...SUBSCRIPTION_PLANS[plan_key] },
  }));
}
