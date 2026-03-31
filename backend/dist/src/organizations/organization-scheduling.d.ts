export type SchedulingMode = 'staff_based' | 'bay_based';
export declare function defaultSchedulingModeForBusinessKind(kind: string | null | undefined): SchedulingMode;
export declare function normalizeSchedulingMode(v: string | null | undefined): SchedulingMode;
