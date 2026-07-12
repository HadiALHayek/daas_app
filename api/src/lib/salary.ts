// Salary engine: attendance -> weekly pay with x1.5 overtime outside 08:00-17:00.
//
// All wall-clock reasoning is done in a fixed timezone (Asia/Damascus, UTC+3).
// We shift UTC epoch millis by the offset so day/hour boundaries can be computed
// with plain arithmetic, then shift back when producing UTC ISO strings.

export const TZ_OFFSET_HOURS = 3; // UTC+3
const OFFSET_MS = TZ_OFFSET_HOURS * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;
const HOUR_MS = 60 * 60 * 1000;

// Per-minute rate basis: 9 working hours x 6 days = 3240 minutes / week.
export const WEEK_MINUTES = 9 * 60 * 6; // 3240
const REGULAR_START_HOUR = 8;
const REGULAR_END_HOUR = 17;

// Morning start grace: clocking in between 08:00 and 08:15 (inclusive) counts
// as an 08:00 start with no deduction. Clocking in at 08:16+ counts from the
// actual arrival time (those minutes are deducted from pay).
export const START_GRACE_MINUTES = 15;

export type WorkSession = { start_at: string; end_at: string | null };
export type LoanRow = { amount: number; loan_date: string };

export type SalaryComputation = {
  regularMin: number;
  overtimeMin: number;
  regularPay: number;
  overtimePay: number;
  gross: number;
  loans: number;
  net: number;
  perMinute: number;
};

export type WeekWindow = {
  /** Inclusive start: Saturday 00:00 local, as a UTC epoch ms. */
  startMs: number;
  /** Exclusive end: following Friday 00:00 local, as a UTC epoch ms. */
  endMs: number;
  startIso: string;
  endIso: string;
  /** Local calendar date of the Saturday (YYYY-MM-DD) — stable week key. */
  startDate: string;
};

/** Local (UTC+3) epoch ms for a given UTC epoch ms. */
function toLocal(ms: number): number {
  return ms + OFFSET_MS;
}

/** Convert a local (UTC+3) epoch ms back to true UTC epoch ms. */
function toUtc(localMs: number): number {
  return localMs - OFFSET_MS;
}

/** Floor a local epoch ms to local midnight. */
function localMidnight(localMs: number): number {
  return Math.floor(localMs / DAY_MS) * DAY_MS;
}

/**
 * Week window for the given offset (0 = current week, -1 = previous, etc.).
 * A week runs Saturday 00:00 -> following Friday 00:00 (local UTC+3).
 */
export function weekWindow(offset: number, now = new Date()): WeekWindow {
  const localNow = toLocal(now.getTime());
  const midnight = localMidnight(localNow);
  // JS day: Sun=0 ... Sat=6. Days elapsed since the most recent Saturday.
  const dow = new Date(midnight).getUTCDay();
  const daysSinceSaturday = (dow - 6 + 7) % 7;
  const startLocal = midnight - daysSinceSaturday * DAY_MS + offset * 7 * DAY_MS;
  const endLocal = startLocal + 6 * DAY_MS; // Friday 00:00

  const startMs = toUtc(startLocal);
  const endMs = toUtc(endLocal);
  return {
    startMs,
    endMs,
    startIso: new Date(startMs).toISOString(),
    endIso: new Date(endMs).toISOString(),
    // startLocal read as UTC fields yields the local wall-clock date.
    startDate: new Date(startLocal).toISOString().slice(0, 10),
  };
}

export type DayWindow = {
  startMs: number;
  endMs: number;
  startIso: string;
  endIso: string;
  /** Local calendar date (YYYY-MM-DD). */
  date: string;
};

/**
 * Day window for a local (UTC+3) calendar date 'YYYY-MM-DD', running from local
 * 00:00 to the next local 00:00.
 */
export function dayWindow(dateStr: string): DayWindow {
  const parts = dateStr.split("-").map((v) => parseInt(v, 10));
  const y = parts[0];
  const m = parts[1] || 1;
  const d = parts[2] || 1;
  // Local midnight expressed as a UTC epoch, then shifted to true UTC.
  const startLocal = Date.UTC(y, m - 1, d);
  const startMs = toUtc(startLocal);
  const endMs = startMs + DAY_MS;
  return {
    startMs,
    endMs,
    startIso: new Date(startMs).toISOString(),
    endIso: new Date(endMs).toISOString(),
    date: new Date(startLocal).toISOString().slice(0, 10),
  };
}

/** Overlap in ms between [aStart,aEnd) and [bStart,bEnd). */
function overlap(aStart: number, aEnd: number, bStart: number, bEnd: number): number {
  return Math.max(0, Math.min(aEnd, bEnd) - Math.max(aStart, bStart));
}

/**
 * Split a set of completed sessions (clamped to the window) into regular and
 * overtime minutes against the daily 08:00-17:00 window.
 */
export function splitSessions(
  sessions: WorkSession[],
  windowStartMs: number,
  windowEndMs: number
): { regularMin: number; overtimeMin: number } {
  let regularMs = 0;
  let totalMs = 0;

  for (const s of sessions) {
    if (!s.end_at) continue; // only completed sessions count
    const rawStart = new Date(s.start_at).getTime();
    const rawEnd = new Date(s.end_at).getTime();
    if (isNaN(rawStart) || isNaN(rawEnd) || rawEnd <= rawStart) continue;

    // Clamp to the week window.
    const start = Math.max(rawStart, windowStartMs);
    const end = Math.min(rawEnd, windowEndMs);
    if (end <= start) continue;

    // Work in local time, walking one calendar day at a time.
    let startLocal = toLocal(start);

    // Apply the morning start grace: if the worker clocked in within the first
    // 15 minutes after 08:00, treat the session as starting exactly at 08:00.
    const sessionDayStart = localMidnight(startLocal);
    const regularStartLocal = sessionDayStart + REGULAR_START_HOUR * HOUR_MS;
    const graceEndLocal = regularStartLocal + START_GRACE_MINUTES * 60000;
    if (startLocal > regularStartLocal && startLocal <= graceEndLocal) {
      startLocal = regularStartLocal;
    }

    let curLocal = startLocal;
    const endLocal = toLocal(end);
    while (curLocal < endLocal) {
      const dayStart = localMidnight(curLocal);
      const dayEnd = dayStart + DAY_MS;
      const segStart = curLocal;
      const segEnd = Math.min(endLocal, dayEnd);

      const regStart = dayStart + REGULAR_START_HOUR * HOUR_MS;
      const regEnd = dayStart + REGULAR_END_HOUR * HOUR_MS;

      totalMs += segEnd - segStart;
      regularMs += overlap(segStart, segEnd, regStart, regEnd);

      curLocal = dayEnd;
    }
  }

  const regularMin = Math.round(regularMs / 60000);
  const totalMin = Math.round(totalMs / 60000);
  const overtimeMin = Math.max(0, totalMin - regularMin);
  return { regularMin, overtimeMin };
}

/** Local (UTC+3) calendar date (YYYY-MM-DD) for a UTC epoch ms. */
export function localDateStr(ms: number): string {
  return new Date(toLocal(ms)).toISOString().slice(0, 10);
}

/** Computed pay for a single day's sessions (regular + 1.5x overtime). */
export function computeDayPay(
  sessions: WorkSession[],
  dayStartMs: number,
  dayEndMs: number,
  perMinute: number
): number {
  const { regularMin, overtimeMin } = splitSessions(
    sessions,
    dayStartMs,
    dayEndMs
  );
  return regularMin * perMinute + overtimeMin * perMinute * 1.5;
}

export function computeSalary(
  weeklySalary: number,
  sessions: WorkSession[],
  loans: LoanRow[],
  win: WeekWindow,
  overrides?: Map<string, number>
): SalaryComputation {
  const perMinute = weeklySalary > 0 ? weeklySalary / WEEK_MINUTES : 0;
  const { regularMin, overtimeMin } = splitSessions(
    sessions,
    win.startMs,
    win.endMs
  );

  const regularPay = regularMin * perMinute;
  const overtimePay = overtimeMin * perMinute * 1.5;

  // Gross = sum of each day's effective pay (manual override when set, else the
  // computed pay). Without overrides this equals regularPay + overtimePay,
  // because splitSessions already sums minutes day by day.
  let gross = 0;
  const numDays = Math.round((win.endMs - win.startMs) / DAY_MS);
  for (let i = 0; i < numDays; i++) {
    const dayStartMs = win.startMs + i * DAY_MS;
    const dayEndMs = dayStartMs + DAY_MS;
    const override = overrides?.get(localDateStr(dayStartMs));
    gross +=
      override != null
        ? override
        : computeDayPay(sessions, dayStartMs, dayEndMs, perMinute);
  }

  const loansTotal = loans.reduce((sum, l) => sum + Number(l.amount), 0);
  const net = gross - loansTotal;

  return {
    regularMin,
    overtimeMin,
    regularPay,
    overtimePay,
    gross,
    loans: loansTotal,
    net,
    perMinute,
  };
}
