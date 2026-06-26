import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError, notFound } from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";

type RouteContext = { params: Promise<{ id: string }> };

function mapBillItem(i: Record<string, unknown>) {
  return {
    ...i,
    quantity: Number(i.quantity),
    unit_sell_price: Number(i.unit_sell_price),
    total_sell: Number(i.total_sell),
    unit_item_cost: Number(i.unit_item_cost ?? 0),
    total_item_cost: Number(i.total_item_cost ?? 0),
  };
}

function mapPayment(p: Record<string, unknown>) {
  return {
    ...p,
    amount: Number(p.amount),
  };
}

export async function GET(request: NextRequest, context: RouteContext) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  const { id } = await context.params;

  try {
    const supabase = getAdminClient();
    const { data: bill, error } = await supabase
      .from("bills")
      .select(
        `
        *,
        customers ( id, name, phone ),
        bill_items ( * ),
        bill_payments ( * )
      `
      )
      .eq("id", id)
      .single();

    if (error || !bill) return notFound();

    const payments = (bill.bill_payments ?? []).map(mapPayment);
    const amountPaid = payments.reduce(
      (sum: number, p: { amount: number }) => sum + p.amount,
      0
    );

    return Response.json({
      ...bill,
      usd_to_syp_rate: Number(bill.usd_to_syp_rate),
      subtotal: Number(bill.subtotal),
      total: Number(bill.total),
      amount_paid: amountPaid,
      amount_remaining: Number(bill.total) - amountPaid,
      items: (bill.bill_items ?? []).map(mapBillItem),
      payments,
    });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
