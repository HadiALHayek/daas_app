import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError } from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";

export async function GET(request: NextRequest) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  try {
    const supabase = getAdminClient();
    const { data, error } = await supabase
      .from("items")
      .select("*")
      .order("created_at", { ascending: false });

    if (error) return serverError(error.message);

    const items = (data ?? []).map((item) => ({
      ...item,
      cost: Number(item.cost),
      sell_price: Number(item.sell_price),
    }));

    return Response.json(items);
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}

export async function POST(request: NextRequest) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  try {
    const body = await request.json();
    const { name, cost, sell_price, currency } = body;

    if (!name || cost == null || sell_price == null || !currency) {
      return Response.json({ error: "جميع الحقول مطلوبة" }, { status: 400 });
    }

    if (!["SYP", "USD"].includes(currency)) {
      return Response.json({ error: "عملة غير صالحة" }, { status: 400 });
    }

    const supabase = getAdminClient();
    const { data, error } = await supabase
      .from("items")
      .insert({
        name,
        cost: Number(cost),
        sell_price: Number(sell_price),
        currency,
      })
      .select()
      .single();

    if (error) return serverError(error.message);

    return Response.json(
      {
        ...data,
        cost: Number(data.cost),
        sell_price: Number(data.sell_price),
      },
      { status: 201 }
    );
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
