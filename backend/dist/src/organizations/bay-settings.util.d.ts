export type OrgBay = {
    id: string;
    name: string;
};
export declare function normalizeOrgBays(slots: unknown): OrgBay[];
export declare function effectiveBayCountFromSlots(slots: unknown): number;
export declare function bayNameMapFromSlots(slots: unknown): Map<string, string>;
