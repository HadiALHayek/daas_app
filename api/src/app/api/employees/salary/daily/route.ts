import { NextRequest } from "next/server";
import {
  verifyAuth,
  unauthorized,
  serverError,
  badRequest,
} from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";
import { dayWindow, splitSessions, WEEK_MINUTES, WorkSession } from "@/lib/salary";
import { pickSalaryRate } from "@/lib/salary-data";

/** Local (UTC+3) calendar date string for "today". */
function todayLocal(): string {
  return new Date(Date.now() + 3 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

// GET /api/employees/salary/daily?date=YYYY-MM-DD
// Per-employee working time + pay for a single day.
export async function GET(request: NextRequest) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  try {
    const dateParam = request.nextUrl.searchParams.get("date");
    const win = dayWindow(dateParam ?? todayLocal());
    const isToday = win.date === todayLocal();

    const supabase = getAdminClient();

    // Sessions that started on this local day.
    const { data: sessions, error: sessError } = await supabase
      .from("work_sessions")
      .select("employee_id, start_at, end_at")
      .gte("start_at", win.startIso)
      .lt("start_at", win.endIso);
    if (sessError) return serverError(sessError.message);

    // Manual salary overrides for this day.
    const { data: overrides, error: ovError } = await supabase
      .from("daily_salary_overrides")
      .select("employee_id, amount")
      .eq("work_date", win.date);
    if (ovError) return serverError(ovError.message);
    const overrideByEmp = new Map<string, number>();
    for (const o of overrides ?? []) {
      overrideByEmp.set(o.employee_id, Number(o.amount));
    }

    const activityIds = new Set<string>();
    for (const s of sessions ?? []) activityIds.add(s.employee_id);
    for (const o of overrides ?? []) activityIds.add(o.employee_id);

    const { data: active, error: empError } = await supabase
      .from("employees")
      .select("id, name, weekly_salary, currency, active")
      .eq("active", true)
      .order("created_at", { ascending: true });
    if (empError) return serverError(empError.message);

    const byId = new Map((active ?? []).map((e) => [e.id as string, e]));
    const missing = Array.from(activityIds).filter((id) => !byId.has(id));
    if (missing.length > 0) {
      const { data: inactive, error: inactiveError } = await supabase
        .from("employees")
        .select("id, name, weekly_salary, currency, active")
        .in("id", missing);
      if (inactiveError) return serverError(inactiveError.message);
      for (const e of inactive ?? []) byId.set(e.id as string, e);
    }

    const employees = Array.from(byId.values()).filter(
      (e) => e.active || activityIds.has(e.id as string) || isToday
    );

    const employeeIds = employees.map((e) => e.id as string);
    let rates: {
      employee_id: string;
      weekly_salary: number;
      effective_from: string;
    }[] = [];
    if (employeeIds.length > 0) {
      const { data: rateRows, error: rateError } = await supabase
        .from("employee_salary_rates")
        .select("employee_id, weekly_salary, effective_from")
        .in("employee_id", employeeIds);
      if (rateError) return serverError(rateError.message);
      rates = (rateRows ?? []) as typeof rates;
    }

    const byEmp = new Map<string, WorkSession[]>();
    for (const s of sessions ?? []) {
      const list = byEmp.get(s.employee_id) ?? [];
      list.push({ start_at: s.start_at, end_at: s.end_at });
      byEmp.set(s.employee_id, list);
    }

    const rows = employees.map((emp) => {
      const list = byEmp.get(emp.id as string) ?? [];
      const weeklySalary = pickSalaryRate(
        rates,
        emp.id as string,
        win.date,
        Number(emp.weekly_salary)
      );
      const perMinute = weeklySalary > 0 ? weeklySalary / WEEK_MINUTES : 0;
      const { regularMin, overtimeMin } = splitSessions(
        list,
        win.startMs,
        win.endMs
      );
      const computedPay =
        regularMin * perMinute + overtimeMin * perMinute * 1.5;
      const override = overrideByEmp.get(emp.id as string);
      const isOverride = override != null;
      const pay = isOverride ? override : computedPay;

      let start: string | null = null;
      let end: string | null = null;
      for (const s of list) {
        if (start == null || s.start_at < start) start = s.start_at;
        if (s.end_at != null && (end == null || s.end_at > end)) end = s.end_at;
      }

      return {
        employee_id: emp.id,
        name: emp.name,
        weekly_salary: weeklySalary,
        per_minute: perMinute,
        regular_min: regularMin,
        overtime_min: overtimeMin,
        pay,
        computed_pay: computedPay,
        is_override: isOverride,
        start_at: start,
        end_at: end,
      };
    });

    return Response.json({
      date: win.date,
      day_start: win.startIso,
      day_end: win.endIso,
      rows,
    });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}

// PUT /api/employees/salary/daily
// Replace an employee's sessions for a given day with a single start->end
// session. Passing null start/end clears the day (marks absent).
export async function PUT(request: NextRequest) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  try {
    const body = await request.json();
    const employeeId = body?.employee_id;
    const dateStr = body?.date;
    if (!employeeId || !dateStr) {
      return badRequest("بيانات ناقصة");
    }

    const win = dayWindow(String(dateStr));
    const supabase = getAdminClient();

    let startIso: string | null = null;
    let endIso: string | null = null;
    if (body?.start_at != null && body?.end_at != null) {
      const start = new Date(body.start_at);
      const end = new Date(body.end_at);
      if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
        return badRequest("وقت غير صالح");
      }
      if (end.getTime() <= start.getTime()) {
        return badRequest("وقت الانصراف يجب أن يكون بعد وقت الحضور");
      }
      startIso = start.toISOString();
      endIso = end.toISOString();
    }

    // Remove existing sessions that started on this day.
    const { error: delError } = await supabase
      .from("work_sessions")
      .delete()
      .eq("employee_id", employeeId)
      .gte("start_at", win.startIso)
      .lt("start_at", win.endIso);
    if (delError) return serverError(delError.message);

    if (startIso && endIso) {
      const { error: insError } = await supabase
        .from("work_sessions")
        .insert({ employee_id: employeeId, start_at: startIso, end_at: endIso });
      if (insError) return serverError(insError.message);
    }

    // Editing the working time recomputes pay, so drop any manual salary
    // override for this day.
    const { error: ovDelError } = await supabase
      .from("daily_salary_overrides")
      .delete()
      .eq("employee_id", employeeId)
      .eq("work_date", win.date);
    if (ovDelError) return serverError(ovDelError.message);

    return Response.json({ success: true });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
