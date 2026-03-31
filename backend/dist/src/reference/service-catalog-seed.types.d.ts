export type CatalogSeedRow = {
    id: string;
    categoryKey: string;
    categoryName: string;
    name: string;
    defaultDurationMinutes: number;
    sortOrder: number;
    requiredSkill?: string | null;
};
