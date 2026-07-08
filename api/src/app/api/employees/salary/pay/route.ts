import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError } from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";
import { weekWindow } from "@/lib/salary";
import { computeWeekRows } from "@/lib/salary-data";

function readOffset(request: NextRequest, bodyWeek?: unknown): number {
  const q = request.nextUrl.searchParams.get("week");
  if (q != null) return parseInt(q, 10) || 0;
  if (bodyWeek != null) return parseInt(String(bodyWeek), 10) || 0;
  return 0;
}

// Pay out the selected week's salaries: for every employee with a positive net
// that hasn't been paid yet, create a 'labor' expense (so it appears in the
// profit report) and record it in salary_payments.
export async function POST(request: NextRequest) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  try {
    let body: Record<string, unknown> = {};
    try {
      body = await request.json();
    } catch {
      body = {};
    }
    const offset = readOffset(request, body.week);
    const win = weekWindow(offset);

    const supabase = getAdminClient();

    // Current exchange rate (the rate on the payout day).
    let rate = 15000;
    const { data: settings } = await supabase
      .from("settings")
      .select("usd_to_syp")
      .eq("id", 1)
      .maybeSingle();
    if (settings) rate = Number(settings.usd_to_syp);

    const computed = await computeWeekRows(supabase, win);

    const { data: paidRows, error: paidError } = await supabase
      .from("salary_payments")
      .select("employee_id")
      .eq("week_start", win.startDate);
    if (paidError) return serverError(paidError.message);
    const paidSet = new Set((paidRows ?? []).map((r) => r.employee_id));

    const nowIso = new Date().toISOString();
    const weekLabel = `${win.startDate} → ${win.endIso.slice(0, 10)}`;
    let paidCount = 0;

    for (const row of computed) {
      if (paidSet.has(row.employeeId)) continue;
      const net = row.comp.net;
      if (net <= 0) continue; // nothing to pay (or loans exceed pay)

      // Mirror into expense_payments so the profit report counts it.
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
      if (expError) return serverError(expError.message);

      const { error: spError } = await supabase.from("salary_payments").insert({
        employee_id: row.employeeId,
        week_start: win.startDate,
        gross: row.comp.gross,
        loans: row.comp.loans,
        net,
        amount: net,
        usd_to_syp_rate: rate,
        expense_payment_id: expense.id,
        paid_at: nowIso,
      });
      if (spError) return serverError(spError.message);

      paidCount += 1;
    }

    return Response.json({ paid_count: paidCount, rate });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}

// Undo the payout for a week: remove the salary_payments rows and their linked
// labor expenses.
export async function DELETE(request: NextRequest) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  try {
    const offset = readOffset(request);
    const win = weekWindow(offset);

    const supabase = getAdminClient();

    const { data: rows, error: findError } = await supabase
      .from("salary_payments")
      .select("id, expense_payment_id")
      .eq("week_start", win.startDate);
    if (findError) return serverError(findError.message);

    const expenseIds = (rows ?? [])
      .map((r) => r.expense_payment_id)
      .filter((v): v is string => !!v);

    if (expenseIds.length > 0) {
      const { error: delExpError } = await supabase
        .from("expense_payments")
        .delete()
        .in("id", expenseIds);
      if (delExpError) return serverError(delExpError.message);
    }

    const { error: delSpError } = await supabase
      .from("salary_payments")
      .delete()
      .eq("week_start", win.startDate);
    if (delSpError) return serverError(delSpError.message);

    return Response.json({ success: true, removed: rows?.length ?? 0 });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
