import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError } from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";
import { weekWindow } from "@/lib/salary";
import { computeWeekRows, finalizeDueWeeks } from "@/lib/salary-data";

export async function GET(request: NextRequest) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  try {
    const offsetParam = request.nextUrl.searchParams.get("week");
    const offset = offsetParam ? parseInt(offsetParam, 10) || 0 : 0;
    const win = weekWindow(offset);

    const supabase = getAdminClient();

    // Auto-pay any finished weeks before reporting (best-effort).
    try {
      await finalizeDueWeeks(supabase);
    } catch (e) {
      console.error("finalizeDueWeeks failed", e);
    }

    const computed = await computeWeekRows(supabase, win);

    // Which employees have already been paid for this week?
    const { data: paidRows, error: paidError } = await supabase
      .from("salary_payments")
      .select("employee_id")
      .eq("week_start", win.startDate);
    if (paidError) return serverError(paidError.message);
    const paidSet = new Set((paidRows ?? []).map((r) => r.employee_id));

    const rows = computed.map((row) => ({
      employee_id: row.employeeId,
      name: row.name,
      weekly_salary: row.weeklySalary,
      currency: row.currency,
      regular_min: row.comp.regularMin,
      overtime_min: row.comp.overtimeMin,
      per_minute: row.comp.perMinute,
      regular_pay: row.comp.regularPay,
      overtime_pay: row.comp.overtimePay,
      gross: row.comp.gross,
      loans: row.comp.loans,
      net: row.comp.net,
      paid: paidSet.has(row.employeeId),
    }));

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
