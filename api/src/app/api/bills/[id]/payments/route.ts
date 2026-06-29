import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError, notFound, badRequest } from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";

type RouteContext = { params: Promise<{ id: string }> };

function mapPayment(row: Record<string, unknown>) {
  return {
    ...row,
    amount: Number(row.amount),
  };
}

export async function GET(request: NextRequest, context: RouteContext) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  const { id: billId } = await context.params;

  try {
    const supabase = getAdminClient();
    const { data, error } = await supabase
      .from("bill_payments")
      .select("*")
      .eq("bill_id", billId)
      .order("payment_date", { ascending: false });

    if (error) return serverError(error.message);

    return Response.json((data ?? []).map(mapPayment));
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}

export async function POST(request: NextRequest, context: RouteContext) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  const { id: billId } = await context.params;

  try {
    const body = await request.json();
    const { amount, notes, payment_date } = body;

    if (amount == null || Number(amount) <= 0) {
      return badRequest("المبلغ مطلوب ويجب أن يكون أكبر من صفر");
    }

    const supabase = getAdminClient();

    const { data: bill, error: billError } = await supabase
      .from("bills")
      .select("id, total")
      .eq("id", billId)
      .single();

    if (billError || !bill) return notFound("الفاتورة غير موجودة");

    const { data: existing, error: sumError } = await supabase
      .from("bill_payments")
      .select("amount")
      .eq("bill_id", billId);

    if (sumError) return serverError(sumError.message);

    const paidSoFar = (existing ?? []).reduce(
      (sum, row) => sum + Number(row.amount),
      0
    );
    const newAmount = Number(amount);
    const billTotal = Number(bill.total);

    if (paidSoFar + newAmount > billTotal + 0.01) {
      return badRequest(
        `المبلغ يتجاوز المتبقي على الفاتورة (${billTotal - paidSoFar})`
      );
    }

    // Get current rate for historical tracking
    let rate = 15000;
    const { data: settings } = await supabase
      .from("settings")
      .select("usd_to_syp")
      .eq("id", 1)
      .maybeSingle();
    if (settings) rate = Number(settings.usd_to_syp);

    const { data, error } = await supabase
      .from("bill_payments")
      .insert({
        bill_id: billId,
        amount: newAmount,
        notes: notes ? String(notes).trim() : null,
        payment_date: payment_date ?? new Date().toISOString(),
        usd_to_syp_rate: rate,
      })
      .select()
      .single();

    if (error) return serverError(error.message);

    return Response.json(mapPayment(data), { status: 201 });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
