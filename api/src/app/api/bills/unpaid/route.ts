import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError } from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";

export async function GET(request: NextRequest) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  try {
    const supabase = getAdminClient();
    const { data, error } = await supabase
      .from("bills")
      .select(
        "*, customers(id, name, phone, address), bill_payments(amount)"
      )
      .order("created_at", { ascending: false });

    if (error) return serverError(error.message);

    const bills = (data ?? [])
      .map((bill) => {
        const payments = (bill.bill_payments as { amount: number }[]) ?? [];
        const amountPaid = Number(
          payments.reduce((sum, p) => sum + Number(p.amount), 0).toFixed(2)
        );
        const total = Number(Number(bill.total).toFixed(2));

        return {
          id: bill.id,
          bill_number: bill.bill_number,
          currency: bill.currency,
          usd_to_syp_rate: Number(bill.usd_to_syp_rate),
          subtotal: Number(bill.subtotal),
          discount: Number(bill.discount ?? 0),
          total,
          seller_signature: bill.seller_signature,
          created_at: bill.created_at,
          customer_id: bill.customer_id,
          customers: bill.customers,
          manual_customer_name: bill.manual_customer_name,
          manual_customer_phone: bill.manual_customer_phone,
          amount_paid: amountPaid,
          amount_remaining: Number((total - amountPaid).toFixed(2)),
        };
      })
      .filter((bill) => bill.amount_remaining > 0.01);

    return Response.json(bills);
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
