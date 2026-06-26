import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError } from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";

type RouteContext = { params: Promise<{ id: string }> };

export async function GET(request: NextRequest, context: RouteContext) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  const { id } = await context.params;

  try {
    const supabase = getAdminClient();
    const { data, error } = await supabase
      .from("bills")
      .select(
        `
        id,
        bill_number,
        currency,
        usd_to_syp_rate,
        subtotal,
        total,
        created_at,
        customers ( id, name, phone )
      `
      )
      .eq("customer_id", id)
      .order("created_at", { ascending: false });

    if (error) return serverError(error.message);

    const bills = (data ?? []).map((bill) => ({
      ...bill,
      usd_to_syp_rate: Number(bill.usd_to_syp_rate),
      subtotal: Number(bill.subtotal),
      total: Number(bill.total),
    }));

    return Response.json(bills);
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
