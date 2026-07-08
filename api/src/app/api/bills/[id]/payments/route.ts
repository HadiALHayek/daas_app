import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError, notFound, badRequest } from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";
import {
  buildBillSnapshot,
  billTotalUsd,
  paymentUsdValue,
} from "@/lib/bill-snapshot";

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

    const { data: existing, error: sumError } = await supabase
      .from("bill_payments")
      .select("amount, original_amount, payment_currency, usd_to_syp_rate")
      .eq("bill_id", billId);

    if (sumError) return serverError(sumError.message);

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
    const billRate = Number(bill.usd_to_syp_rate) || rate;
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

    // Validate against the remaining debt in USD terms: the debt is pegged to
    // its dollar value, so what matters is that we never collect more than the
    // outstanding USD balance regardless of the currency/rate used to pay.
    const totalUsd = billTotalUsd(Number(bill.total), billCurrency, billRate);
    const paidUsd = (existing ?? []).reduce(
      (sum, row) => sum + paymentUsdValue(row, billCurrency, billRate),
      0
    );
    const newPaymentUsd = paymentUsdValue(
      {
        amount: amountInBillCurrency,
        original_amount: originalAmount,
        payment_currency: paymentCurrency,
        usd_to_syp_rate: rate,
      },
      billCurrency,
      billRate
    );

    if (paidUsd + newPaymentUsd > totalUsd + 0.01) {
      const remainingUsd = Math.max(0, totalUsd - paidUsd);
      const remainingLabel =
        billCurrency === "USD"
          ? `${remainingUsd.toFixed(2)} $`
          : `${(remainingUsd * rate).toFixed(0)} ل.س`;
      return badRequest(`المبلغ يتجاوز المتبقي على الفاتورة (${remainingLabel})`);
    }

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
