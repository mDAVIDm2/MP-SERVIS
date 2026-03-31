export declare const ORGANIZATION_BUSINESS_KINDS: readonly ["sto", "car_wash", "detailing", "car_audio", "tire_service", "body_shop", "glass", "tuning", "ev_service", "other"];
export type OrganizationBusinessKind = (typeof ORGANIZATION_BUSINESS_KINDS)[number];
export declare function normalizeOrganizationBusinessKind(v: string | null | undefined): OrganizationBusinessKind;
