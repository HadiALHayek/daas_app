import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError, notFound, badRequest } from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";
import { buildBillSnapshot } from "@/lib/bill-snapshot";

type RouteContext = { params: Promise<{ id: string }> };

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

    return Response.json(
      (data ?? []).map((row) => ({
        ...row,
        amount: Number(row.amount),
        usd_to_syp_rate:
          row.usd_to_syp_rate == null ? null : Number(row.usd_to_syp_rate),
        original_amount:
          row.original_amount == null ? null : Number(row.original_amount),
      }))
    );
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
      .select("id, total, currency, usd_to_syp_rate")
      .eq("id", billId)
      .single();

    if (billError || !bill) return notFound("الفاتورة غير موجودة");

    let rate = 15000;
    const { data: settings } = await supabase
      .from("settings")
      .select("usd_to_syp")
      .eq("id", 1)
      .maybeSingle();
    if (settings && Number(settings.usd_to_syp) > 0) {
      rate = Number(settings.usd_to_syp);
    }

    const billCurrency = bill.currency === "USD" ? "USD" : "SYP";
    const paymentCurrency = body.currency === "USD" ? "USD" : "SYP";
    const originalAmount = Number(amount);

    // Convert the entered amount into the bill's currency at today's rate so the
    // nominal `amount` column stays in the bill currency.
    let amountInBillCurrency = originalAmount;
    if (paymentCurrency !== billCurrency) {
      amountInBillCurrency =
        paymentCurrency === "USD"
          ? originalAmount * rate // USD -> SYP
          : originalAmount / rate; // SYP -> USD
    }
    amountInBillCurrency = Number(amountInBillCurrency.toFixed(2));

    // Overpayment is intentionally allowed (e.g. rounding a 39.5 balance up to
    // 40). Any excess simply settles the remaining balance to zero.

    const { error: insertError } = await supabase.from("bill_payments").insert({
      bill_id: billId,
      amount: amountInBillCurrency,
      original_amount: originalAmount,
      payment_currency: paymentCurrency,
      notes: notes ? String(notes).trim() : null,
      payment_date: payment_date ?? new Date().toISOString(),
      usd_to_syp_rate: rate,
    });

    if (insertError) return serverError(insertError.message);

    const snapshot = await buildBillSnapshot(supabase, billId);
    if (!snapshot) {
      return serverError("تم تسجيل الدفعة ولكن فشل استرجاع الفاتورة");
    }

    return Response.json(snapshot, { status: 201 });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
