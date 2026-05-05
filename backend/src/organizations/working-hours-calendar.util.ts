import { DateTime } from 'luxon';

export type WorkingHoursWeekDay = { open: string; close: string; closed?: boolean };
export type WorkingHoursException = { date: string; closed?: boolean; open?: string; close?: string };

function parseHm(t: string): number {
  const [h, m] = t.split(':').map((x) => parseInt(x, 10));
  return (h ?? 0) * 60 + (m ?? 0);
}

export function formatHmFromMinutes(mins: number): string {
  const h = Math.floor(mins / 60);
  const m = mins % 60;
  const mm = m < 10 ? `0${m}` : `${m}`;
  return `${h}:${mm}`;
}

/** Эффективное окно приёма для календарной даты в зоне организации. */
export function resolveEffectiveDayMinutes(opts: {
  dateLocal: DateTime;
  week: WorkingHoursWeekDay[] | null | undefined;
  exceptions: WorkingHoursException[] | null | undefined;
}): { closed: boolean; openM: number; closeM: number } | null {
  const dateStr = opts.dateLocal.toFormat('yyyy-MM-dd');
  const ex = (opts.exceptions ?? []).find((e) => e.date === dateStr);
  if (ex) {
    if (ex.closed === true) return { closed: true, openM: 0, closeM: 0 };
    const o = ex.open?.trim();
    const c = ex.close?.trim();
    const re = /^([01]\d|2[0-3]):[0-5]\d$/;
    if (o && c && re.test(o) && re.test(c)) {
      const openM = parseHm(o);
      const closeM = parseHm(c);
      if (closeM > openM) return { closed: false, openM, closeM };
    }
  }
  const week = opts.week;
  if (!week || week.length !== 7) return null;
  const idx = opts.dateLocal.weekday === 7 ? 6 : opts.dateLocal.weekday - 1;
  const d = week[idx];
  if (!d || d.closed === true) return { closed: true, openM: 0, closeM: 0 };
  return { closed: false, openM: parseHm(d.open), closeM: parseHm(d.close) };
}

export type HoursLiveDto = {
  state:
    | 'open'
    | 'open_until'
    | 'closed_until_today'
    | 'closed_until_future'
    | 'day_off'
    | 'exception_closed'
    | 'unknown';
  close_hm?: string;
  next_open_hm?: string;
  next_open_date?: string;
};

function findNextOpeningLocal(
  from: DateTime,
  week: WorkingHoursWeekDay[] | null | undefined,
  exceptions: WorkingHoursException[] | null | undefined,
): { dateStr: string; hm: string } | null {
  for (let i = 1; i <= 14; i++) {
    const d = from.startOf('day').plus({ days: i });
    const eff = resolveEffectiveDayMinutes({ dateLocal: d, week, exceptions });
    if (!eff || eff.closed) continue;
    return { dateStr: d.toFormat('yyyy-MM-dd'), hm: formatHmFromMinutes(eff.openM) };
  }
  return null;
}

/** Статус строки мини-карточки «сейчас» для зоны организации. */
export function computeOrganizationHoursLive(opts: {
  timezone: string;
  week: WorkingHoursWeekDay[] | null | undefined;
  exceptions: WorkingHoursException[] | null | undefined;
  now?: DateTime;
}): HoursLiveDto {
  const zone = opts.timezone?.trim() || 'Europe/Moscow';
  const nowLocal = (opts.now ?? DateTime.now()).setZone(zone);

  const eff = resolveEffectiveDayMinutes({
    dateLocal: nowLocal,
    week: opts.week,
    exceptions: opts.exceptions,
  });
  if (eff == null) return { state: 'unknown' };

  const dateStr = nowLocal.toFormat('yyyy-MM-dd');
  const exToday = (opts.exceptions ?? []).find((e) => e.date === dateStr);

  if (eff.closed) {
    if (exToday?.closed === true) return { state: 'exception_closed' };
    return { state: 'day_off' };
  }

  const { openM, closeM } = eff;
  const cur = nowLocal.hour * 60 + nowLocal.minute;

  if (cur < openM) {
    return {
      state: 'closed_until_today',
      next_open_hm: formatHmFromMinutes(openM),
    };
  }
  if (cur >= closeM) {
    const next = findNextOpeningLocal(nowLocal, opts.week, opts.exceptions);
    if (!next) return { state: 'closed_until_future' };
    return {
      state: 'closed_until_future',
      next_open_hm: next.hm,
      next_open_date: next.dateStr,
    };
  }

  const minsToClose = closeM - cur;
  if (minsToClose <= 30) {
    return { state: 'open_until', close_hm: formatHmFromMinutes(closeM) };
  }
  return { state: 'open' };
}
