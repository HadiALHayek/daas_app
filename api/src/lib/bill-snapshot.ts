import { getAdminClient } from "@/lib/supabase";

type SupabaseAdmin = ReturnType<typeof getAdminClient>;

function mapPayment(p: Record<string, unknown>) {
  return {
    ...p,
    amount: Number(p.amount),
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
  excludeBillId?: string
) {
  let query = supabase
    .from("bills")
    .select("id, bill_number, total, currency, bill_payments(amount)")
    .eq("customer_id", customerId)
    .order("created_at", { ascending: false });

  if (excludeBillId) {
    query = query.neq("id", excludeBillId);
  }

  const { data: otherBills } = await query;

  if (!otherBills) return [];

  return otherBills
    .map((b: Record<string, unknown>) => {
      const payments = (b.bill_payments as Record<string, unknown>[]) ?? [];
      const paid = payments.reduce(
        (sum, p) => sum + Number(p.amount),
        0
      );
      const remaining = Number((Number(b.total) - paid).toFixed(2));
      return {
        id: b.id as string,
        bill_number: Number(b.bill_number),
        total: Number(b.total),
        amount_remaining: remaining,
        currency: b.currency as string,
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

  let outstandingBills: Awaited<ReturnType<typeof fetchOutstandingBills>> = [];
  if (bill.customer_id) {
    outstandingBills = await fetchOutstandingBills(
      supabase,
      bill.customer_id,
      billId
    );
  }

  return {
    ...bill,
    usd_to_syp_rate: Number(bill.usd_to_syp_rate),
    subtotal: Number(bill.subtotal),
    discount: Number(bill.discount ?? 0),
    total,
    amount_paid: amountPaid,
    amount_remaining: Number((total - amountPaid).toFixed(2)),
    items,
    payments,
    outstanding_bills: outstandingBills,
  };
}
