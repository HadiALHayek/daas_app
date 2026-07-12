import { NextRequest } from "next/server";
import {
  verifyAuth,
  unauthorized,
  serverError,
  badRequest,
} from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";
import { dayWindow } from "@/lib/salary";

// PUT /api/employees/salary/daily/amount
// Set (or update) a manual salary override for an employee on a given day.
export async function PUT(request: NextRequest) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  try {
    const body = await request.json();
    const employeeId = body?.employee_id;
    const dateStr = body?.date;
    const amount = body?.amount;

    if (!employeeId || !dateStr) return badRequest("بيانات ناقصة");
    if (amount == null || !Number.isFinite(Number(amount)) || Number(amount) < 0) {
      return badRequest("مبلغ غير صالح");
    }

    const win = dayWindow(String(dateStr));
    const supabase = getAdminClient();

    const { error } = await supabase.from("daily_salary_overrides").upsert(
      {
        employee_id: employeeId,
        work_date: win.date,
        amount: Number(amount),
        updated_at: new Date().toISOString(),
      },
      { onConflict: "employee_id,work_date" }
    );
    if (error) return serverError(error.message);

    return Response.json({ success: true });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}

// DELETE /api/employees/salary/daily/amount?employee_id=...&date=YYYY-MM-DD
// Remove the override so the day reverts to computed pay.
export async function DELETE(request: NextRequest) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  try {
    const employeeId = request.nextUrl.searchParams.get("employee_id");
    const dateStr = request.nextUrl.searchParams.get("date");
    if (!employeeId || !dateStr) return badRequest("بيانات ناقصة");

    const win = dayWindow(dateStr);
    const supabase = getAdminClient();

    const { error } = await supabase
      .from("daily_salary_overrides")
      .delete()
      .eq("employee_id", employeeId)
      .eq("work_date", win.date);
    if (error) return serverError(error.message);

    return Response.json({ success: true });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
