import { SupabaseClient } from "@supabase/supabase-js";
import {
  WeekWindow,
  WorkSession,
  LoanRow,
  computeSalary,
  SalaryComputation,
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
