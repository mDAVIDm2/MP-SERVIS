/** Именованные посты/боксы в настройках организации: slots.bays */

export type OrgBay = { id: string; name: string };

export function normalizeOrgBays(slots: unknown): OrgBay[] {
  if (slots === null || typeof slots !== 'object') return [];
  const bays = (slots as { bays?: unknown }).bays;
  if (!Array.isArray(bays)) return [];
  const out: OrgBay[] = [];
  for (const b of bays) {
    if (b === null || typeof b !== 'object') continue;
    const id = String((b as { id?: string }).id ?? '').trim();
    const name = String((b as { name?: string }).name ?? '').trim() || 'Пост';
    if (id.length > 0) out.push({ id, name });
  }
  return out;
}

/** Число постов: именованные боксы или fallback на bay_count (1–20). */
export function effectiveBayCountFromSlots(slots: unknown): number {
  const named = normalizeOrgBays(slots);
  if (named.length > 0) return Math.min(20, named.length);
  if (slots === null || typeof slots !== 'object') return 3;
  const n = Number((slots as { bay_count?: number }).bay_count);
  return Math.max(1, Math.min(20, Number.isFinite(n) && n > 0 ? n : 3));
}

export function bayNameMapFromSlots(slots: unknown): Map<string, string> {
  const m = new Map<string, string>();
  for (const b of normalizeOrgBays(slots)) {
    m.set(b.id, b.name);
  }
  return m;
}
