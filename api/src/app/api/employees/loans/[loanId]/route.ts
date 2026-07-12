import { NextRequest } from "next/server";
import {
  verifyAuth,
  unauthorized,
  serverError,
  badRequest,
} from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";

type RouteContext = { params: Promise<{ loanId: string }> };

export async function PUT(request: NextRequest, context: RouteContext) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  const { loanId } = await context.params;

  try {
    const body = await request.json();
    const { amount, note } = body;

    const updates: Record<string, unknown> = {};
    if (amount != null) {
      if (Number(amount) <= 0) return badRequest("المبلغ مطلوب");
      updates.amount = Number(amount);
    }
    if (note !== undefined) {
      updates.note = note ? String(note).trim() : null;
    }
    if (Object.keys(updates).length === 0) {
      return badRequest("لا يوجد تغيير");
    }

    const supabase = getAdminClient();
    const { data, error } = await supabase
      .from("employee_loans")
      .update(updates)
      .eq("id", loanId)
      .select()
      .single();

    if (error) return serverError(error.message);

    return Response.json({ ...data, amount: Number(data.amount) });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}

export async function DELETE(request: NextRequest, context: RouteContext) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  const { loanId } = await context.params;

  try {
    const supabase = getAdminClient();
    const { error } = await supabase
      .from("employee_loans")
      .delete()
      .eq("id", loanId);

    if (error) return serverError(error.message);

    return Response.json({ success: true });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
