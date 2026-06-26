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
    const currency = body?.currency;
    const seller_signature = body?.seller_signature ?? body?.sellerSignature ?? "";
    const items = body?.items;

    if (!customer_id) {
      return Response.json({ error: "العميل مطلوب" }, { status: 400 });
    }
    if (!currency) {
      return Response.json({ error: "العملة مطلوبة" }, { status: 400 });
    }
    if (!Array.isArray(items) || items.length === 0) {
      return Response.json({ error: "أضف صنفاً واحداً على الأقل" }, { status: 400 });
    }

    if (!["SYP", "USD"].includes(currency)) {
      return Response.json({ error: "عملة غير صالحة" }, { status: 400 });
    }

    const supabase = getAdminClient();

    let rate = 15000;
    const { data: settings, error: settingsError } = await supabase
      .from("settings")
      .select("usd_to_syp")
      .eq("id", 1)
      .maybeSingle();

    if (settingsError) return serverError(settingsError.message);

    if (settings) {
      rate = Number(settings.usd_to_syp);
    } else {
      const { error: seedError } = await supabase
        .from("settings")
        .upsert({ id: 1, usd_to_syp: rate });
      if (seedError) return serverError(seedError.message);
    }
    const processedItems = [];

    for (const line of items as BillLineInput[]) {
      let unitSell = Number(line.unit_sell_price ?? 0);
      let unitCost = Number(line.unit_item_cost ?? 0);
      const itemCurrency = line.item_currency ?? currency;

      if (line.item_id) {
        const { data: catalogItem, error: itemError } = await supabase
          .from("items")
          .select("*")
          .eq("id", line.item_id)
          .single();

        if (itemError || !catalogItem) {
          return Response.json(
            { error: `الصنف غير موجود: ${line.item_name}` },
            { status: 400 }
          );
        }

        unitSell = await convertToBillCurrency(
          Number(catalogItem.sell_price),
          catalogItem.currency,
          currency,
          rate
        );
        unitCost = await convertToBillCurrency(
          Number(catalogItem.cost),
          catalogItem.currency,
          currency,
          rate
        );
      }

      const quantity = Number(line.quantity) || 1;
      processedItems.push({
        item_id: line.item_id ?? null,
        item_name: line.item_name,
        quantity,
        unit_sell_price: unitSell,
        total_sell: unitSell * quantity,
        unit_item_cost: unitCost,
        total_item_cost: unitCost * quantity,
      });
    }

    const subtotal = processedItems.reduce((sum, i) => sum + i.total_sell, 0);
    const total = subtotal;

    const { data: bill, error: billError } = await supabase
      .from("bills")
      .insert({
        customer_id,
        currency,
        usd_to_syp_rate: rate,
        subtotal,
        total,
        seller_signature: seller_signature ?? '',
      })
      .select(
        `
        *,
        customers ( id, name, phone )
      `
      )
      .single();

    if (billError) return serverError(billError.message);

    const billItems = processedItems.map((item) => ({
      ...item,
      bill_id: bill.id,
    }));

    const { data: insertedItems, error: itemsError } = await supabase
      .from("bill_items")
      .insert(billItems)
      .select();

    if (itemsError) return serverError(itemsError.message);

    return Response.json(
      {
        ...bill,
        usd_to_syp_rate: Number(bill.usd_to_syp_rate),
        subtotal: Number(bill.subtotal),
        total: Number(bill.total),
        items: (insertedItems ?? []).map((i) => ({
          ...i,
          quantity: Number(i.quantity),
          unit_sell_price: Number(i.unit_sell_price),
          total_sell: Number(i.total_sell),
          unit_item_cost: Number(i.unit_item_cost),
          total_item_cost: Number(i.total_item_cost),
        })),
      },
      { status: 201 }
    );
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
