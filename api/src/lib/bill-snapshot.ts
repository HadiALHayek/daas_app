import { getAdminClient } from "@/lib/supabase";

type SupabaseAdmin = ReturnType<typeof getAdminClient>;

/** Current USD→SYP rate from settings, falling back to a sane default. */
export async function getCurrentRate(supabase: SupabaseAdmin): Promise<number> {
  const { data } = await supabase
    .from("settings")
    .select("usd_to_syp")
    .eq("id", 1)
    .maybeSingle();
  const rate = data ? Number(data.usd_to_syp) : 15000;
  return rate > 0 ? rate : 15000;
}

type PaymentLike = {
  amount: number;
  original_amount?: number | null;
  payment_currency?: string | null;
  usd_to_syp_rate?: number | null;
};

/** USD value of a single payment, using the rate in effect when it was made. */
export function paymentUsdValue(
  p: PaymentLike,
  billCurrency: string,
  billRate: number
): number {
  const currency = p.payment_currency ?? billCurrency;
  const original = p.original_amount ?? p.amount;
  const rate = p.usd_to_syp_rate ?? billRate;
  if (currency === "USD") return original;
  if (!rate) return 0;
  return original / rate; // SYP -> USD
}

/** USD value of the bill total, using the rate at bill creation. */
export function billTotalUsd(
  total: number,
  billCurrency: string,
  billRate: number
): number {
  if (billCurrency === "USD") return total;
  return billRate ? total / billRate : 0;
}

/**
 * The remaining debt, pegged to its USD value. Because the debt is really in
 * USD, the SYP amount owed is re-evaluated at *today's* rate: a customer who
 * still owes $66.67 owes 933,333 SYP when the rate is 14,000 even if that debt
 * originally read 1,000,000 SYP at a rate of 15,000.
 */
export function remainingAtCurrentRate(args: {
  total: number;
  billCurrency: string;
  billRate: number;
  payments: PaymentLike[];
  currentRate: number;
}): { remaining: number; remainingUsd: number } {
  const { total, billCurrency, billRate, payments, currentRate } = args;
  const totalUsd = billTotalUsd(total, billCurrency, billRate);
  const paidUsd = payments.reduce(
    (sum, p) => sum + paymentUsdValue(p, billCurrency, billRate),
    0
  );
  let remainingUsd = totalUsd - paidUsd;
  if (remainingUsd < 0.01) remainingUsd = 0;
  const remaining =
    billCurrency === "USD" ? remainingUsd : remainingUsd * currentRate;
  return {
    remaining: Number(remaining.toFixed(2)),
    remainingUsd: Number(remainingUsd.toFixed(2)),
  };
}

function mapPayment(p: Record<string, unknown>) {
  return {
    ...p,
    amount: Number(p.amount),
    usd_to_syp_rate:
      p.usd_to_syp_rate == null ? null : Number(p.usd_to_syp_rate),
    original_amount:
      p.original_amount == null ? null : Number(p.original_amount),
  };
}

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

export async function fetchOutstandingBills(
  supabase: SupabaseAdmin,
  customerId: string,
  excludeBillId?: string,
  currentRate?: number
) {
  let query = supabase
    .from("bills")
    .select(
      "id, bill_number, total, currency, usd_to_syp_rate, bill_payments(amount, original_amount, payment_currency, usd_to_syp_rate)"
    )
    .eq("customer_id", customerId)
    .order("created_at", { ascending: false });

  if (excludeBillId) {
    query = query.neq("id", excludeBillId);
  }

  const { data: otherBills } = await query;

  if (!otherBills) return [];

  const rate = currentRate ?? (await getCurrentRate(supabase));

  return otherBills
    .map((b: Record<string, unknown>) => {
      const rawPayments =
        (b.bill_payments as Record<string, unknown>[]) ?? [];
      const currency = b.currency as string;
      const billRate = Number(b.usd_to_syp_rate) || rate;
      const payments: PaymentLike[] = rawPayments.map((p) => ({
        amount: Number(p.amount),
        original_amount:
          p.original_amount == null ? null : Number(p.original_amount),
        payment_currency: (p.payment_currency as string | null) ?? null,
        usd_to_syp_rate:
          p.usd_to_syp_rate == null ? null : Number(p.usd_to_syp_rate),
      }));
      const { remaining, remainingUsd } = remainingAtCurrentRate({
        total: Number(b.total),
        billCurrency: currency,
        billRate,
        payments,
        currentRate: rate,
      });
      return {
        id: b.id as string,
        bill_number: Number(b.bill_number),
        total: Number(b.total),
        amount_remaining: remaining,
        amount_remaining_usd: remainingUsd,
        currency,
      };
    })
    .filter((b) => b.amount_remaining > 0.01);
}

export async function buildBillSnapshot(
  supabase: SupabaseAdmin,
  billId: string
) {
  const [billResult, paymentsResult, itemsResult] = await Promise.all([
    supabase.from("bills").select("*, customers(*)").eq("id", billId).single(),
    supabase
      .from("bill_payments")
      .select("*")
      .eq("bill_id", billId)
      .order("payment_date", { ascending: true }),
    supabase.from("bill_items").select("*").eq("bill_id", billId),
  ]);

  if (billResult.error || !billResult.data) return null;

  const bill = billResult.data;
  const payments = (paymentsResult.data ?? []).map(mapPayment);
  const items = (itemsResult.data ?? []).map(mapBillItem);
  const amountPaid = Number(
    payments.reduce((sum, p) => sum + p.amount, 0).toFixed(2)
  );
  const total = Number(Number(bill.total).toFixed(2));
  const currentRate = await getCurrentRate(supabase);
  const billCurrency = (bill.currency as string) ?? "SYP";
  const billRate = Number(bill.usd_to_syp_rate) || currentRate;

  const { remaining, remainingUsd } = remainingAtCurrentRate({
    total,
    billCurrency,
    billRate,
    payments,
    currentRate,
  });

  let outstandingBills: Awaited<ReturnType<typeof fetchOutstandingBills>> = [];
  if (bill.customer_id) {
    outstandingBills = await fetchOutstandingBills(
      supabase,
      bill.customer_id,
      billId,
      currentRate
    );
  }

  return {
    ...bill,
    usd_to_syp_rate: Number(bill.usd_to_syp_rate),
    current_rate: currentRate,
    subtotal: Number(bill.subtotal),
    discount: Number(bill.discount ?? 0),
    total,
    amount_paid: amountPaid,
    amount_remaining: remaining,
    amount_remaining_usd: remainingUsd,
    items,
    payments,
    outstanding_bills: outstandingBills,
  };
}
