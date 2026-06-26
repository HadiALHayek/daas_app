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
    const { name, phone } = body;

    if (!name || String(name).trim() === "") {
      return Response.json({ error: "اسم العميل مطلوب" }, { status: 400 });
    }

    const supabase = getAdminClient();
    const { data, error } = await supabase
      .from("customers")
      .update({
        name: String(name).trim(),
        phone: phone ? String(phone).trim() : null,
      })
      .eq("id", id)
      .select()
      .single();

    if (error || !data) return notFound();

    return Response.json(data);
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

    const { data: bills, error: billsQueryError } = await supabase
      .from("bills")
      .select("id")
      .eq("customer_id", id);

    if (billsQueryError) return serverError(billsQueryError.message);

    if (bills?.length) {
      const billIds = bills.map((bill) => bill.id);
      const { error: billsDeleteError } = await supabase
        .from("bills")
        .delete()
        .in("id", billIds);

      if (billsDeleteError) return serverError(billsDeleteError.message);
    }

    const { error } = await supabase.from("customers").delete().eq("id", id);

    if (error) return serverError(error.message);

    return Response.json({ success: true });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
