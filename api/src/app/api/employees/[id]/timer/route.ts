import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError, badRequest } from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";

type RouteContext = { params: Promise<{ id: string }> };

export async function POST(request: NextRequest, context: RouteContext) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  const { id } = await context.params;

  try {
    const body = await request.json();
    const action = body?.action;
    if (action !== "start" && action !== "stop") {
      return badRequest("إجراء غير صالح");
    }

    const supabase = getAdminClient();

    // Find the currently open session for this employee, if any.
    const { data: openSessions, error: findError } = await supabase
      .from("work_sessions")
      .select("id, start_at")
      .eq("employee_id", id)
      .is("end_at", null)
      .order("start_at", { ascending: false });

    if (findError) return serverError(findError.message);

    const open = openSessions && openSessions.length > 0 ? openSessions[0] : null;

    if (action === "start") {
      if (open) {
        // Already running; return the existing session (idempotent).
        return Response.json({
          id: open.id,
          start_at: open.start_at,
          running: true,
        });
      }
      const { data, error } = await supabase
        .from("work_sessions")
        .insert({ employee_id: id })
        .select()
        .single();
      if (error) return serverError(error.message);
      return Response.json(
        { id: data.id, start_at: data.start_at, running: true },
        { status: 201 }
      );
    }

    // action === "stop"
    if (!open) {
      return badRequest("لا يوجد مؤقت قيد التشغيل");
    }
    const { data, error } = await supabase
      .from("work_sessions")
      .update({ end_at: new Date().toISOString() })
      .eq("id", open.id)
      .select()
      .single();
    if (error) return serverError(error.message);
    return Response.json({
      id: data.id,
      start_at: data.start_at,
      end_at: data.end_at,
      running: false,
    });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
