import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError, notFound } from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";

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
    // Sessions and loans cascade via the FK on delete.
    const { error } = await supabase.from("employees").delete().eq("id", id);

    if (error) return serverError(error.message);

    return Response.json({ success: true });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
