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

/**
 * Fetch active employees, their sessions overlapping the window, and their
 * loans within the window, and compute each one's salary for that week.
 */
export async function computeWeekRows(
  supabase: SupabaseClient,
  win: WeekWindow
): Promise<EmployeeWeekRow[]> {
  const { data: employees, error: empError } = await supabase
    .from("employees")
    .select("id, name, weekly_salary, currency")
    .eq("active", true)
    .order("created_at", { ascending: true });
  if (empError) throw new Error(empError.message);

  const { data: sessions, error: sessError } = await supabase
    .from("work_sessions")
    .select("employee_id, start_at, end_at")
    .lt("start_at", win.endIso)
    .gte("end_at", win.startIso);
  if (sessError) throw new Error(sessError.message);

  const { data: loans, error: loanError } = await supabase
    .from("employee_loans")
    .select("employee_id, amount, loan_date")
    .gte("loan_date", win.startIso)
    .lt("loan_date", win.endIso);
  if (loanError) throw new Error(loanError.message);

  const sessionsByEmp = new Map<string, WorkSession[]>();
  for (const s of sessions ?? []) {
    const list = sessionsByEmp.get(s.employee_id) ?? [];
    list.push({ start_at: s.start_at, end_at: s.end_at });
    sessionsByEmp.set(s.employee_id, list);
  }

  const loansByEmp = new Map<string, LoanRow[]>();
  for (const l of loans ?? []) {
    const list = loansByEmp.get(l.employee_id) ?? [];
    list.push({ amount: Number(l.amount), loan_date: l.loan_date });
    loansByEmp.set(l.employee_id, list);
  }

  return (employees ?? []).map((emp) => ({
    employeeId: emp.id,
    name: emp.name,
    weeklySalary: Number(emp.weekly_salary),
    currency: emp.currency,
    comp: computeSalary(
      Number(emp.weekly_salary),
      sessionsByEmp.get(emp.id) ?? [],
      loansByEmp.get(emp.id) ?? [],
      win
    ),
  }));
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
  rate: number
): Promise<number> {
  const computed = await computeWeekRows(supabase, win);

  const { data: paidRows, error: paidError } = await supabase
    .from("salary_payments")
    .select("employee_id")
    .eq("week_start", win.startDate);
  if (paidError) throw new Error(paidError.message);
  const paidSet = new Set((paidRows ?? []).map((r) => r.employee_id));

  const nowIso = new Date().toISOString();
  const weekLabel = `${win.startDate} → ${win.endIso.slice(0, 10)}`;
  let count = 0;

  for (const row of computed) {
    if (paidSet.has(row.employeeId)) continue;
    const net = row.comp.net;
    if (net <= 0) continue; // nothing to pay (or loans exceed pay)

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

  return count;
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
    total += await payWeek(supabase, win, rate);
  }
  return total;
}
