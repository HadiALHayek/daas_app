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
    const { name, sell_price, currency } = body;

    const updates: Record<string, unknown> = {};
    if (name != null) updates.name = name;
    if (sell_price != null) updates.sell_price = Number(sell_price);
    if (currency != null) {
      if (!["SYP", "USD"].includes(currency)) {
        return Response.json({ error: "عملة غير صالحة" }, { status: 400 });
      }
      updates.currency = currency;
    }

    const supabase = getAdminClient();
    const { data, error } = await supabase
      .from("items")
      .update(updates)
      .eq("id", id)
      .select()
      .single();

    if (error) return notFound();
    if (!data) return notFound();

    return Response.json({
      ...data,
      cost: Number(data.cost),
      sell_price: Number(data.sell_price),
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
    const { error } = await supabase.from("items").delete().eq("id", id);

    if (error) return serverError(error.message);

    return Response.json({ success: true });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
