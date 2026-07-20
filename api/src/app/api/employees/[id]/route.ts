import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError, notFound } from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";
import { weekWindow } from "@/lib/salary";
import { upsertSalaryRate } from "@/lib/salary-data";

type RouteContext = { params: Promise<{ id: string }> };

export async function PUT(request: NextRequest, context: RouteContext) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  const { id } = await context.params;

  try {
    const body = await request.json();
    const { name, weekly_salary } = body;

    const updates: Record<string, unknown> = {};
    if (name != null) {
      if (String(name).trim() === "") {
        return Response.json({ error: "الاسم مطلوب" }, { status: 400 });
      }
      updates.name = String(name).trim();
    }
    if (weekly_salary != null) {
      if (Number(weekly_salary) < 0) {
        return Response.json({ error: "الراتب غير صالح" }, { status: 400 });
      }
      updates.weekly_salary = Number(weekly_salary);
    }

    const supabase = getAdminClient();
    const { data, error } = await supabase
      .from("employees")
      .update(updates)
      .eq("id", id)
      .select()
      .single();

    if (error || !data) return notFound();

    // New salary applies from the start of the current week onward; past weeks
    // keep the previous rate from employee_salary_rates history.
    if (weekly_salary != null) {
      try {
        await upsertSalaryRate(
          supabase,
          id,
          Number(weekly_salary),
          weekWindow(0).startDate
        );
      } catch (e) {
        console.error("upsertSalaryRate on update failed", e);
      }
    }

    return Response.json({
      id: data.id,
      name: data.name,
      weekly_salary: Number(data.weekly_salary),
      currency: data.currency,
      active: data.active,
      created_at: data.created_at,
    });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}

export async function DELETE(request: NextRequest, context: RouteContext) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  const { id } = await context.params;

  try {
    const supabase = getAdminClient();

    // Soft-delete: keep the worker row and all historical sessions, loans,
    // overrides and salary payments. Only hide them from the active list.
    const nowIso = new Date().toISOString();
    await supabase
      .from("work_sessions")
      .update({ end_at: nowIso })
      .eq("employee_id", id)
      .is("end_at", null);

    const { data, error } = await supabase
      .from("employees")
      .update({ active: false })
      .eq("id", id)
      .select("id")
      .maybeSingle();

    if (error) return serverError(error.message);
    if (!data) return notFound();

    return Response.json({ success: true });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
