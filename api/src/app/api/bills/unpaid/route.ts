import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError } from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";
import { getCurrentRate, remainingAtCurrentRate } from "@/lib/bill-snapshot";

export async function GET(request: NextRequest) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  try {
    const supabase = getAdminClient();
    const { data, error } = await supabase
      .from("bills")
      .select(
        "*, customers(id, name, phone, address), bill_payments(amount, original_amount, payment_currency, usd_to_syp_rate)"
      )
      .order("created_at", { ascending: false });

    if (error) return serverError(error.message);

    const currentRate = await getCurrentRate(supabase);

    const bills = (data ?? [])
      .map((bill) => {
        const rawPayments =
          (bill.bill_payments as Record<string, unknown>[]) ?? [];
        const amountPaid = Number(
          rawPayments
            .reduce((sum, p) => sum + Number(p.amount), 0)
            .toFixed(2)
        );
        const total = Number(Number(bill.total).toFixed(2));
        const billCurrency = (bill.currency as string) ?? "SYP";
        const billRate = Number(bill.usd_to_syp_rate) || currentRate;

        const { remaining, remainingUsd } = remainingAtCurrentRate({
          total,
          billCurrency,
          billRate,
          payments: rawPayments.map((p) => ({
            amount: Number(p.amount),
            original_amount:
              p.original_amount == null ? null : Number(p.original_amount),
            payment_currency: (p.payment_currency as string | null) ?? null,
            usd_to_syp_rate:
              p.usd_to_syp_rate == null ? null : Number(p.usd_to_syp_rate),
          })),
          currentRate,
        });

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
          amount_remaining: remaining,
          amount_remaining_usd: remainingUsd,
        };
      })
      .filter((bill) => bill.amount_remaining > 0.01);

    return Response.json(bills);
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
