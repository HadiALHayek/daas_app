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
      // Optional manual arrival time. Lets the user backdate the start when
      // they forgot to press start the moment the worker arrived.
      let startAt: string | undefined;
      if (body?.start_at != null) {
        const parsed = new Date(body.start_at);
        if (Number.isNaN(parsed.getTime())) {
          return badRequest("وقت غير صالح");
        }
        // Allow a small clock-skew tolerance but reject clearly future times.
        if (parsed.getTime() > Date.now() + 60_000) {
          return badRequest("وقت الوصول لا يمكن أن يكون في المستقبل");
        }
        startAt = parsed.toISOString();
      }

      if (open) {
        // Already running. If a manual arrival time was provided, update the
        // open session's start time (editing the timer). Otherwise idempotent.
        if (startAt) {
          const { data, error } = await supabase
            .from("work_sessions")
            .update({ start_at: startAt })
            .eq("id", open.id)
            .select()
            .single();
          if (error) return serverError(error.message);
          return Response.json({
            id: data.id,
            start_at: data.start_at,
            running: true,
          });
        }
        return Response.json({
          id: open.id,
          start_at: open.start_at,
          running: true,
        });
      }

      const insertPayload: { employee_id: string; start_at?: string } = {
        employee_id: id,
      };
      if (startAt) insertPayload.start_at = startAt;
      const { data, error } = await supabase
        .from("work_sessions")
        .insert(insertPayload)
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

    // Optional manual end (departure) time. Lets the admin backdate the stop
    // when they forgot to press stop the moment the worker left. When
    // allow_future is set (e.g. the "finish at 5 PM" button pressed before 5),
    // a future end time is accepted, capped to one day ahead as a sanity bound.
    const allowFuture = body?.allow_future === true;
    let endAt = new Date().toISOString();
    if (body?.end_at != null) {
      const parsed = new Date(body.end_at);
      if (Number.isNaN(parsed.getTime())) {
        return badRequest("وقت غير صالح");
      }
      const futureLimit = allowFuture ? 24 * 60 * 60 * 1000 : 60_000;
      if (parsed.getTime() > Date.now() + futureLimit) {
        return badRequest("وقت الانصراف لا يمكن أن يكون في المستقبل");
      }
      if (parsed.getTime() <= new Date(open.start_at).getTime()) {
        return badRequest("وقت الانصراف يجب أن يكون بعد وقت الوصول");
      }
      endAt = parsed.toISOString();
    }

    const { data, error } = await supabase
      .from("work_sessions")
      .update({ end_at: endAt })
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
