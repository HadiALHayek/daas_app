import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError } from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";
import {
  weekWindow,
  computeSalary,
  WorkSession,
  LoanRow,
} from "@/lib/salary";

export async function GET(request: NextRequest) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  try {
    const offsetParam = request.nextUrl.searchParams.get("week");
    const offset = offsetParam ? parseInt(offsetParam, 10) || 0 : 0;
    const win = weekWindow(offset);

    const supabase = getAdminClient();

    const { data: employees, error: empError } = await supabase
      .from("employees")
      .select("id, name, weekly_salary, currency")
      .eq("active", true)
      .order("created_at", { ascending: true });

    if (empError) return serverError(empError.message);

    // Sessions overlapping the window: started before window end and either
    // still open or ended after window start.
    const { data: sessions, error: sessError } = await supabase
      .from("work_sessions")
      .select("employee_id, start_at, end_at")
      .lt("start_at", win.endIso)
      .gte("end_at", win.startIso);

    if (sessError) return serverError(sessError.message);

    const { data: loans, error: loanError } = await supabase
      .from("employee_loans")
      .select("employee_id, amount, loan_date")
      .gte("loan_date", win.startIso)
      .lt("loan_date", win.endIso);

    if (loanError) return serverError(loanError.message);

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

    const rows = (employees ?? []).map((emp) => {
      const comp = computeSalary(
        Number(emp.weekly_salary),
        sessionsByEmp.get(emp.id) ?? [],
        loansByEmp.get(emp.id) ?? [],
        win
      );
      return {
        employee_id: emp.id,
        name: emp.name,
        weekly_salary: Number(emp.weekly_salary),
        currency: emp.currency,
        regular_min: comp.regularMin,
        overtime_min: comp.overtimeMin,
        per_minute: comp.perMinute,
        regular_pay: comp.regularPay,
        overtime_pay: comp.overtimePay,
        gross: comp.gross,
        loans: comp.loans,
        net: comp.net,
      };
    });

    return Response.json({
      week_offset: offset,
      week_start: win.startIso,
      week_end: win.endIso,
      rows,
    });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
