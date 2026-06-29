import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError } from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";
import { convertToBillCurrency } from "@/lib/currency";

interface BillLineInput {
  item_id?: string;
  item_name: string;
  quantity: number;
  unit_sell_price?: number;
  unit_item_cost?: number;
  item_currency?: string;
}

export async function POST(request: NextRequest) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  try {
    const body = await request.json();
    const customer_id = body?.customer_id ?? body?.customerId;
    const manual_customer_name = body?.manual_customer_name ?? body?.manualCustomerName;
    const manual_customer_phone = body?.manual_customer_phone ?? body?.manualCustomerPhone;
    const currency = body?.currency;
    const seller_signature = body?.seller_signature ?? body?.sellerSignature ?? "";
    const items = body?.items;
    const discount = Math.max(0, Number(body?.discount ?? 0));
    const initial_payment = body?.initial_payment ?? body?.initialPayment ?? body?.amount_paid ?? null;

    if (!customer_id && !manual_customer_name) {
      return Response.json({ error: "العميل مطلوب" }, { status: 400 });
    }
    if (!currency || !Array.isArray(items) || items.length === 0) {
      return Response.json({ error: "البيانات غير مكتملة" }, { status: 400 });
    }

    const supabase = getAdminClient();

    // 1. Get Exchange Rate
    let rate = 15000;
    const { data: settings } = await supabase.from("settings").select("usd_to_syp").eq("id", 1).maybeSingle();
    if (settings) rate = Number(settings.usd_to_syp);

    // 2. Process Items
    const processedItems = [];
    for (const line of items as BillLineInput[]) {
      let unitSell = Number(line.unit_sell_price ?? 0);
      let unitCost = 0;
      const hasPriceOverride = line.unit_sell_price != null && Number(line.unit_sell_price) > 0;

      if (line.item_id) {
        const { data: catalogItem } = await supabase.from("items").select("*").eq("id", line.item_id).single();
        if (catalogItem) {
          if (!hasPriceOverride) {
            unitSell = await convertToBillCurrency(Number(catalogItem.sell_price), catalogItem.currency, currency, rate);
          }
          unitCost = await convertToBillCurrency(Number(catalogItem.cost), catalogItem.currency, currency, rate);
        }
      }

      const quantity = Number(line.quantity) || 1;
      processedItems.push({
        item_id: line.item_id ?? null,
        item_name: line.item_name,
        quantity,
        unit_sell_price: unitSell,
        total_sell: Number((unitSell * quantity).toFixed(2)),
        unit_item_cost: unitCost,
        total_item_cost: Number((unitCost * quantity).toFixed(2)),
      });
    }

    const subtotal = processedItems.reduce((sum, i) => sum + i.total_sell, 0);
    const total = Number((subtotal - discount).toFixed(2));

    // 3. Insert Bill
    const { data: bill, error: billError } = await supabase
      .from("bills")
      .insert({
        customer_id: customer_id || null,
        manual_customer_name: manual_customer_name || null,
        manual_customer_phone: manual_customer_phone || null,
        currency,
        usd_to_syp_rate: rate,
        subtotal,
        discount,
        total,
        seller_signature: seller_signature || "manual",
      })
      .select()
      .single();

    if (billError) {
      console.error("Bill Insert Error:", billError);
      return serverError(`فشل إنشاء الفاتورة: ${billError.message}`);
    }

    // 4. Insert Items
    const { error: itemsError } = await supabase
      .from("bill_items")
      .insert(processedItems.map(i => ({ ...i, bill_id: bill.id })));

    if (itemsError) {
      console.error("Items Insert Error:", itemsError);
      return serverError(`فشل إضافة الأصناف: ${itemsError.message}`);
    }

    // 5. Insert Payment if provided
    const paymentAmount = initial_payment != null ? Number(Number(initial_payment).toFixed(2)) : null;
    if (paymentAmount != null && paymentAmount > 0) {
      const { error: paymentError } = await supabase.from("bill_payments").insert({
        bill_id: bill.id,
        amount: Math.min(paymentAmount, total),
        notes: "دفع نقدي فوراً",
        usd_to_syp_rate: rate,
      });
      if (paymentError) console.error("Initial Payment Error:", paymentError);
    }

    // 6. Fresh Fetch: Get the complete bill state from DB
    const { data: finalBill, error: fetchError } = await supabase
      .from("bills")
      .select("*, customers(*), bill_items(*), bill_payments(*)")
      .eq("id", bill.id)
      .single();

    if (fetchError || !finalBill) return serverError("فشل استرجاع البيانات المحدثة");

    const payments = (finalBill.bill_payments ?? []).map((p: any) => ({ ...p, amount: Number(p.amount) }));
    const amountPaid = payments.reduce((sum: number, p: any) => sum + p.amount, 0);

    return Response.json({
      ...finalBill,
      usd_to_syp_rate: Number(finalBill.usd_to_syp_rate),
      subtotal: Number(finalBill.subtotal),
      discount: Number(finalBill.discount ?? 0),
      total: Number(finalBill.total),
      amount_paid: amountPaid,
      amount_remaining: Number((Number(finalBill.total) - amountPaid).toFixed(2)),
      items: (finalBill.bill_items ?? []).map((i: any) => ({
        ...i,
        quantity: Number(i.quantity),
        unit_sell_price: Number(i.unit_sell_price),
        total_sell: Number(i.total_sell),
      })),
      payments,
    }, { status: 201 });

  } catch (e) {
    console.error("Unexpected Error:", e);
    return serverError(e instanceof Error ? e.message : "خطأ غير متوقع");
  }
}
