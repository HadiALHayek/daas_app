import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError } from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";
import { weekWindow } from "@/lib/salary";
import { getCurrentRate, payWeek } from "@/lib/salary-data";

function readOffset(request: NextRequest, bodyWeek?: unknown): number {
  const q = request.nextUrl.searchParams.get("week");
  if (q != null) return parseInt(q, 10) || 0;
  if (bodyWeek != null) return parseInt(String(bodyWeek), 10) || 0;
  return 0;
}

// Manual override: pay out the selected week's salaries now. Normally salaries
// are finalized automatically once a week ends (see finalizeDueWeeks), so this
// is only used to force an early/explicit payout.
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
    const rate = await getCurrentRate(supabase);
    const paidCount = await payWeek(supabase, win, rate);

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
