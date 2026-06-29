import { NextRequest } from "next/server";
import {
  verifyAuth,
  unauthorized,
  serverError,
  notFound,
  badRequest,
} from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";

type RouteContext = { params: { id: string } };

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

  const id = context.params.id;

  try {
    const supabase = getAdminClient();

    // Fetch bill and payments separately to ensure reliability
    const [billResult, paymentsResult, itemsResult] = await Promise.all([
      supabase
        .from("bills")
        .select("*, customers(*)")
        .eq("id", id)
        .single(),
      supabase
        .from("bill_payments")
        .select("*")
        .eq("bill_id", id)
        .order("payment_date", { ascending: true }),
      supabase
        .from("bill_items")
        .select("*")
        .eq("bill_id", id)
    ]);

    if (billResult.error || !billResult.data) return notFound();

    const bill = billResult.data;
    const payments = (paymentsResult.data ?? []).map(mapPayment);
    const items = (itemsResult.data ?? []).map(mapBillItem);

    const amountPaid = Number(payments.reduce((sum, p) => sum + p.amount, 0).toFixed(2));
    const total = Number(Number(bill.total).toFixed(2));

    let outstandingBills: any[] = [];
    if (bill.customer_id) {
      // Fetch other unpaid bills for this customer
      const { data: otherBills } = await supabase
        .from("bills")
        .select("id, bill_number, total, currency, bill_payments(amount)")
        .eq("customer_id", bill.customer_id)
        .neq("id", id)
        .order("created_at", { ascending: false });

      if (otherBills) {
        outstandingBills = otherBills
          .map((b: any) => {
            const paid = (b.bill_payments ?? []).reduce(
              (sum: number, p: any) => sum + Number(p.amount),
              0
            );
            const remaining = Number((Number(b.total) - paid).toFixed(2));
            return {
              id: b.id,
              bill_number: b.bill_number,
              total: Number(b.total),
              amount_remaining: remaining,
              currency: b.currency,
            };
          })
          .filter((b) => b.amount_remaining > 0.01);
      }
    }

    return Response.json({
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
    });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}

interface BillLineUpdate {
  id: string;
  unit_sell_price?: number;
  quantity?: number;
}

export async function PUT(request: NextRequest, context: RouteContext) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  const id = context.params.id;

  try {
    const body = await request.json();
    const discount =
      body?.discount != null ? Math.max(0, Number(body.discount)) : null;
    const items = body?.items as BillLineUpdate[] | undefined;

    const supabase = getAdminClient();

    const { data: bill, error: billError } = await supabase
      .from("bills")
      .select("*, bill_items(*), bill_payments(*)")
      .eq("id", id)
      .single();

    if (billError || !bill) return notFound();

    if (items?.length) {
      for (const line of items) {
        if (!line.id) continue;
        const existing = (bill.bill_items as any[]).find((i) => i.id === line.id);
        if (!existing) continue;

        const unitPrice =
          line.unit_sell_price != null
            ? Number(line.unit_sell_price)
            : Number(existing.unit_sell_price);
        const quantity =
          line.quantity != null
            ? Number(line.quantity)
            : Number(existing.quantity);

        if (unitPrice < 0 || quantity <= 0) {
          return badRequest("بيانات الصنف غير صالحة");
        }

        await supabase
          .from("bill_items")
          .update({
            unit_sell_price: unitPrice,
            quantity,
            total_sell: Number((unitPrice * quantity).toFixed(2)),
          })
          .eq("id", line.id);
      }
    }

    const { data: updatedItems } = await supabase
      .from("bill_items")
      .select("*")
      .eq("bill_id", id);

    const subtotal = (updatedItems ?? []).reduce(
      (sum, i) => sum + Number(i.total_sell),
      0
    );
    const newDiscount =
      discount != null ? discount : Number(bill.discount ?? 0);
    const total = Number((subtotal - newDiscount).toFixed(2));

    const payments = (bill.bill_payments as any[] ?? []).map(mapPayment);
    const amountPaid = payments.reduce((sum, p) => sum + p.amount, 0);

    if (total < amountPaid - 0.01) {
      return badRequest("لا يمكن أن يكون الإجمالي أقل من المبلغ المدفوع");
    }

    const { data: updatedBill, error: updateError } = await supabase
      .from("bills")
      .update({
        subtotal: Number(subtotal.toFixed(2)),
        discount: Number(newDiscount.toFixed(2)),
        total
      })
      .eq("id", id)
      .select("*, customers(*)")
      .single();

    if (updateError) return serverError(updateError.message);

    return Response.json({
      ...updatedBill,
      amount_paid: amountPaid,
      amount_remaining: Number((total - amountPaid).toFixed(2)),
      items: (updatedItems ?? []).map(mapBillItem),
      payments,
    });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}

export async function DELETE(request: NextRequest, context: RouteContext) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  const id = context.params.id;

  try {
    const supabase = getAdminClient();
    const { error } = await supabase.from("bills").delete().eq("id", id);

    if (error) return serverError(error.message);

    return Response.json({ success: true });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
