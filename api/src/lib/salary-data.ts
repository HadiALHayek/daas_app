import { SupabaseClient } from "@supabase/supabase-js";
import {
  WeekWindow,
  WorkSession,
  LoanRow,
  computeSalary,
  SalaryComputation,
  weekWindow,
} from "./salary";

export type EmployeeWeekRow = {
  employeeId: string;
  name: string;
  weeklySalary: number;
  currency: string;
  comp: SalaryComputation;
};

type SalaryRateRow = {
  employee_id: string;
  weekly_salary: number;
  effective_from: string;
};

/**
 * Record (or update) the weekly salary that applies from [effectiveFrom]
 * onward. Past weeks keep whatever older rate was already stored.
 */
export async function upsertSalaryRate(
  supabase: SupabaseClient,
  employeeId: string,
  weeklySalary: number,
  effectiveFrom: string
): Promise<void> {
  const { error } = await supabase.from("employee_salary_rates").upsert(
    {
      employee_id: employeeId,
      weekly_salary: weeklySalary,
      effective_from: effectiveFrom,
    },
    { onConflict: "employee_id,effective_from" }
  );
  if (error) throw new Error(error.message);
}

/**
 * Pick the weekly salary in effect on [asOfDate] (YYYY-MM-DD): the latest
 * rate whose effective_from is on or before that date. Falls back to
 * [fallback] when no history exists yet.
 */
export function pickSalaryRate(
  rates: SalaryRateRow[],
  employeeId: string,
  asOfDate: string,
  fallback: number
): number {
  let best: SalaryRateRow | null = null;
  for (const r of rates) {
    if (r.employee_id !== employeeId) continue;
    const from = String(r.effective_from).slice(0, 10);
    if (from > asOfDate) continue;
    if (!best || from > String(best.effective_from).slice(0, 10)) best = r;
  }
  return best ? Number(best.weekly_salary) : fallback;
}

async function loadSalaryRates(
  supabase: SupabaseClient,
  employeeIds: string[]
): Promise<SalaryRateRow[]> {
  if (employeeIds.length === 0) return [];
  const { data, error } = await supabase
    .from("employee_salary_rates")
    .select("employee_id, weekly_salary, effective_from")
    .in("employee_id", employeeIds)
    .order("effective_from", { ascending: true });
  if (error) throw new Error(error.message);
  return (data ?? []) as SalaryRateRow[];
}

/**
 * Fetch employees for a week: always active ones, plus any inactive workers
 * who still have sessions / loans / overrides in that window (so soft-deleted
 * workers keep showing up in historical reports).
 */
async function loadEmployeesForWindow(
  supabase: SupabaseClient,
  activityIds: Set<string>
): Promise<
  { id: string; name: string; weekly_salary: number; currency: string; active: boolean }[]
> {
  const { data: active, error: activeError } = await supabase
    .from("employees")
    .select("id, name, weekly_salary, currency, active")
    .eq("active", true)
    .order("created_at", { ascending: true });
  if (activeError) throw new Error(activeError.message);

  const byId = new Map(
    (active ?? []).map((e) => [e.id as string, e])
  );

  const missing = Array.from(activityIds).filter((id) => !byId.has(id));
  if (missing.length > 0) {
    const { data: inactive, error: inactiveError } = await supabase
      .from("employees")
      .select("id, name, weekly_salary, currency, active")
      .in("id", missing);
    if (inactiveError) throw new Error(inactiveError.message);
    for (const e of inactive ?? []) byId.set(e.id as string, e);
  }

  return Array.from(byId.values()).map((e) => ({
    id: e.id as string,
    name: e.name as string,
    weekly_salary: Number(e.weekly_salary),
    currency: e.currency as string,
    active: !!e.active,
  }));
}

/**
 * Fetch active employees, their sessions overlapping the window, and their
 * loans for that week, and compute each one's salary.
 * Uses the salary rate that was in effect at the start of the week so editing
 * a worker's salary later does not rewrite past weeks.
 *
 * Loans: unsettled loans are deducted on the next payday. Once salaries are
 * paid for a week, those loans are marked settled for that week — they remain
 * on that week's report, and the next week starts clear.
 */
export async function computeWeekRows(
  supabase: SupabaseClient,
  win: WeekWindow
): Promise<EmployeeWeekRow[]> {
  const { data: sessions, error: sessError } = await supabase
    .from("work_sessions")
    .select("employee_id, start_at, end_at")
    .lt("start_at", win.endIso)
    .gte("end_at", win.startIso);
  if (sessError) throw new Error(sessError.message);

  // Which employees are already paid for this week?
  const { data: paidRows, error: paidError } = await supabase
    .from("salary_payments")
    .select("employee_id")
    .eq("week_start", win.startDate);
  if (paidError) throw new Error(paidError.message);
  const paidSet = new Set((paidRows ?? []).map((r) => r.employee_id as string));
  const weekIsPaid = paidSet.size > 0;

  // Paid week → loans settled on this payday (historical).
  // Unpaid week → all still-open (unsettled) loans that will clear on pay.
  let loans: { employee_id: string; amount: number; loan_date: string }[] = [];
  if (weekIsPaid) {
    const { data, error: loanError } = await supabase
      .from("employee_loans")
      .select("employee_id, amount, loan_date")
      .eq("settled_week_start", win.startDate);
    if (loanError) throw new Error(loanError.message);
    loans = data ?? [];
  } else {
    const { data, error: loanError } = await supabase
      .from("employee_loans")
      .select("employee_id, amount, loan_date")
      .is("settled_week_start", null)
      .lt("loan_date", win.endIso);
    if (loanError) throw new Error(loanError.message);
    loans = data ?? [];
  }

  const { data: overrides, error: ovError } = await supabase
    .from("daily_salary_overrides")
    .select("employee_id, work_date, amount")
    .gte("work_date", win.startDate)
    .lt("work_date", win.endIso.slice(0, 10));
  if (ovError) throw new Error(ovError.message);

  const activityIds = new Set<string>();
  for (const s of sessions ?? []) activityIds.add(s.employee_id);
  for (const l of loans) activityIds.add(l.employee_id);
  for (const o of overrides ?? []) activityIds.add(o.employee_id);

  const employees = await loadEmployeesForWindow(supabase, activityIds);
  const rates = await loadSalaryRates(
    supabase,
    employees.map((e) => e.id)
  );

  const sessionsByEmp = new Map<string, WorkSession[]>();
  for (const s of sessions ?? []) {
    const list = sessionsByEmp.get(s.employee_id) ?? [];
    list.push({ start_at: s.start_at, end_at: s.end_at });
    sessionsByEmp.set(s.employee_id, list);
  }

  const loansByEmp = new Map<string, LoanRow[]>();
  for (const l of loans) {
    // For an unpaid week that is already partly paid (rare), only attach
    // unsettled loans to workers who are not yet paid for this week.
    if (!weekIsPaid && paidSet.has(l.employee_id)) continue;
    const list = loansByEmp.get(l.employee_id) ?? [];
    list.push({ amount: Number(l.amount), loan_date: l.loan_date });
    loansByEmp.set(l.employee_id, list);
  }

  // For a paid week, also show settled loans on workers who appear only via
  // payments (already in paidSet / activity). For unpaid, unsettled loans may
  // belong to active workers with no sessions yet — activityIds covers that.

  const overridesByEmp = new Map<string, Map<string, number>>();
  for (const o of overrides ?? []) {
    const map = overridesByEmp.get(o.employee_id) ?? new Map<string, number>();
    map.set(String(o.work_date).slice(0, 10), Number(o.amount));
    overridesByEmp.set(o.employee_id, map);
  }

  // Active workers always appear; inactive ones only if they had activity
  // in this window (soft-deleted workers keep historical rows).
  return employees.map((emp) => {
    const weeklySalary = pickSalaryRate(
      rates,
      emp.id,
      win.startDate,
      emp.weekly_salary
    );
    return {
      employeeId: emp.id,
      name: emp.name,
      weeklySalary,
      currency: emp.currency,
      comp: computeSalary(
        weeklySalary,
        sessionsByEmp.get(emp.id) ?? [],
        loansByEmp.get(emp.id) ?? [],
        win,
        overridesByEmp.get(emp.id)
      ),
    };
  });
}

/** Mark all unsettled loans for [employeeIds] as settled on this payday. */
export async function settleLoansForWeek(
  supabase: SupabaseClient,
  win: WeekWindow,
  employeeIds: string[]
): Promise<void> {
  if (employeeIds.length === 0) return;
  const { error } = await supabase
    .from("employee_loans")
    .update({ settled_week_start: win.startDate })
    .in("employee_id", employeeIds)
    .is("settled_week_start", null)
    .lt("loan_date", win.endIso);
  if (error) throw new Error(error.message);
}

/** Undo loan settlement when a week's payout is reversed. */
export async function unsettleLoansForWeek(
  supabase: SupabaseClient,
  win: WeekWindow
): Promise<void> {
  const { error } = await supabase
    .from("employee_loans")
    .update({ settled_week_start: null })
    .eq("settled_week_start", win.startDate);
  if (error) throw new Error(error.message);
}

/** Current USD→SYP rate from settings (falls back to 15000). */
export async function getCurrentRate(
  supabase: SupabaseClient
): Promise<number> {
  const { data } = await supabase
    .from("settings")
    .select("usd_to_syp")
    .eq("id", 1)
    .maybeSingle();
  return data ? Number(data.usd_to_syp) : 15000;
}

/**
 * Record (pay out) the salaries for a single week. For every employee with a
 * positive net that isn't already paid, insert a salary_payments row (this also
 * acts as the uniqueness guard) and a mirroring 'labor' expense so it appears
 * in the profit report at the given rate. Returns how many were paid.
 */
export async function payWeek(
  supabase: SupabaseClient,
  win: WeekWindow,
  rate: number,
  overrideAmount?: number
): Promise<{ count: number; total: number }> {
  const computed = await computeWeekRows(supabase, win);

  const { data: paidRows, error: paidError } = await supabase
    .from("salary_payments")
    .select("employee_id")
    .eq("week_start", win.startDate);
  if (paidError) throw new Error(paidError.message);
  const paidSet = new Set((paidRows ?? []).map((r) => r.employee_id));

  const nowIso = new Date().toISOString();
  const weekLabel = `${win.startDate} → ${win.endIso.slice(0, 10)}`;

  const payable = computed.filter(
    (row) => !paidSet.has(row.employeeId) && row.comp.net > 0
  );
  if (payable.length === 0) return { count: 0, total: 0 };

  const computedTotal = payable.reduce((s, r) => s + r.comp.net, 0);

  // Override path (manual confirm from the salary screen): record a single
  // combined labor expense for the admin-entered total (defaults to the
  // computed total) instead of one expense per employee. Individual
  // salary_payments rows are still written so the "paid" markers and the
  // undo/unpay flow keep working.
  if (overrideAmount != null) {
    const insertedIds: string[] = [];
    for (const row of payable) {
      const { data: sp, error: spError } = await supabase
        .from("salary_payments")
        .insert({
          employee_id: row.employeeId,
          week_start: win.startDate,
          gross: row.comp.gross,
          loans: row.comp.loans,
          net: row.comp.net,
          amount: row.comp.net,
          usd_to_syp_rate: rate,
          paid_at: nowIso,
        })
        .select()
        .single();
      if (spError) {
        if ((spError as { code?: string }).code === "23505") continue;
        throw new Error(spError.message);
      }
      insertedIds.push(sp.id);
    }
    if (insertedIds.length === 0) return { count: 0, total: 0 };

    const { data: expense, error: expError } = await supabase
      .from("expense_payments")
      .insert({
        title: "رواتب الأسبوع",
        category: "labor",
        amount: overrideAmount,
        currency: "SYP",
        notes: `أسبوع ${weekLabel}`,
        payment_date: nowIso,
        usd_to_syp_rate: rate,
      })
      .select()
      .single();
    if (expError) throw new Error(expError.message);

    const { error: linkError } = await supabase
      .from("salary_payments")
      .update({ expense_payment_id: expense.id })
      .in("id", insertedIds);
    if (linkError) throw new Error(linkError.message);

    await settleLoansForWeek(
      supabase,
      win,
      payable.map((r) => r.employeeId)
    );

    return { count: insertedIds.length, total: overrideAmount };
  }

  // Default path (automatic weekly finalization): one salary_payment plus one
  // mirroring labor expense per employee.
  let count = 0;
  for (const row of payable) {
    const net = row.comp.net;

    // Insert the salary record first — the unique(employee_id, week_start)
    // constraint guards against double-paying under concurrent finalizations.
    const { data: sp, error: spError } = await supabase
      .from("salary_payments")
      .insert({
        employee_id: row.employeeId,
        week_start: win.startDate,
        gross: row.comp.gross,
        loans: row.comp.loans,
        net,
        amount: net,
        usd_to_syp_rate: rate,
        paid_at: nowIso,
      })
      .select()
      .single();
    if (spError) {
      // 23505 = unique violation: already paid (possibly by a concurrent run).
      if ((spError as { code?: string }).code === "23505") continue;
      throw new Error(spError.message);
    }

    const { data: expense, error: expError } = await supabase
      .from("expense_payments")
      .insert({
        title: `راتب أسبوعي - ${row.name}`,
        category: "labor",
        amount: net,
        currency: "SYP",
        notes: `أسبوع ${weekLabel}`,
        payment_date: nowIso,
        usd_to_syp_rate: rate,
      })
      .select()
      .single();
    if (expError) throw new Error(expError.message);

    await supabase
      .from("salary_payments")
      .update({ expense_payment_id: expense.id })
      .eq("id", sp.id);

    count += 1;
  }

  if (count > 0) {
    await settleLoansForWeek(
      supabase,
      win,
      payable.map((r) => r.employeeId)
    );
  }

  return { count, total: computedTotal };
}

/**
 * Auto-finalize every week that has already ended (its Friday 00:00 has
 * passed) and hasn't been paid yet, going back `lookback` weeks. This is the
 * "automatic Thursday/Friday payout" — it runs lazily whenever salary or
 * profit data is loaded, so no scheduler is required. Already-paid weeks are
 * skipped, so it's cheap to call repeatedly.
 */
export async function finalizeDueWeeks(
  supabase: SupabaseClient,
  lookback = 5
): Promise<number> {
  const rate = await getCurrentRate(supabase);
  const now = Date.now();
  let total = 0;
  for (let off = 0; off >= -lookback; off--) {
    const win = weekWindow(off);
    if (win.endMs > now) continue; // week still in progress — don't pay yet
    total += (await payWeek(supabase, win, rate)).count;
  }
  return total;
}
