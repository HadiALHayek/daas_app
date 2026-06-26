import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError, notFound } from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";

type RouteContext = { params: Promise<{ id: string }> };

const CATEGORIES = ["materials", "transport", "labor", "other"] as const;

export async function PUT(request: NextRequest, context: RouteContext) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  const { id } = await context.params;

  try {
    const body = await request.json();
    const { title, category, amount, currency, notes, payment_date } = body;

    const updates: Record<string, unknown> = {};
    if (title != null) updates.title = String(title).trim();
    if (category != null) {
      if (!CATEGORIES.includes(category)) {
        return Response.json({ error: "التصنيف غير صالح" }, { status: 400 });
      }
      updates.category = category;
    }
    if (amount != null) {
      if (Number(amount) <= 0) {
        return Response.json({ error: "المبلغ غير صالح" }, { status: 400 });
      }
      updates.amount = Number(amount);
    }
    if (currency != null) {
      if (!["SYP", "USD"].includes(currency)) {
        return Response.json({ error: "عملة غير صالحة" }, { status: 400 });
      }
      updates.currency = currency;
    }
    if (notes !== undefined) updates.notes = notes ? String(notes).trim() : null;
    if (payment_date != null) updates.payment_date = payment_date;

    const supabase = getAdminClient();
    const { data, error } = await supabase
      .from("expense_payments")
      .update(updates)
      .eq("id", id)
      .select()
      .single();

    if (error || !data) return notFound();

    return Response.json({ ...data, amount: Number(data.amount) });
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
    const { error } = await supabase
      .from("expense_payments")
      .delete()
      .eq("id", id);

    if (error) return serverError(error.message);

    return Response.json({ success: true });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
