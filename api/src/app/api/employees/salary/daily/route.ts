import { NextRequest } from "next/server";
import {
  verifyAuth,
  unauthorized,
  serverError,
  badRequest,
} from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";
import { dayWindow, splitSessions, WEEK_MINUTES, WorkSession } from "@/lib/salary";

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

    const supabase = getAdminClient();

    const { data: employees, error: empError } = await supabase
      .from("employees")
      .select("id, name, weekly_salary, currency")
      .eq("active", true)
      .order("created_at", { ascending: true });
    if (empError) return serverError(empError.message);

    // Sessions that started on this local day.
    const { data: sessions, error: sessError } = await supabase
      .from("work_sessions")
      .select("employee_id, start_at, end_at")
      .gte("start_at", win.startIso)
      .lt("start_at", win.endIso);
    if (sessError) return serverError(sessError.message);

    const byEmp = new Map<string, WorkSession[]>();
    for (const s of sessions ?? []) {
      const list = byEmp.get(s.employee_id) ?? [];
      list.push({ start_at: s.start_at, end_at: s.end_at });
      byEmp.set(s.employee_id, list);
    }

    const rows = (employees ?? []).map((emp) => {
      const list = byEmp.get(emp.id) ?? [];
      const perMinute =
        Number(emp.weekly_salary) > 0
          ? Number(emp.weekly_salary) / WEEK_MINUTES
          : 0;
      const { regularMin, overtimeMin } = splitSessions(
        list,
        win.startMs,
        win.endMs
      );
      const pay = regularMin * perMinute + overtimeMin * perMinute * 1.5;

      // Effective clock-in/out for display: earliest start, latest end.
      let start: string | null = null;
      let end: string | null = null;
      for (const s of list) {
        if (start == null || s.start_at < start) start = s.start_at;
        if (s.end_at != null && (end == null || s.end_at > end)) end = s.end_at;
      }

      return {
        employee_id: emp.id,
        name: emp.name,
        weekly_salary: Number(emp.weekly_salary),
        per_minute: perMinute,
        regular_min: regularMin,
        overtime_min: overtimeMin,
        pay,
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

    return Response.json({ success: true });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
