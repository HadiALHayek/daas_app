import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError } from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";

const CATEGORIES = ["materials", "transport", "labor", "other"] as const;

export async function GET(request: NextRequest) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  try {
    const supabase = getAdminClient();
    const { data, error } = await supabase
      .from("expense_payments")
      .select("*")
      .order("payment_date", { ascending: false });

    if (error) return serverError(error.message);

    return Response.json(
      (data ?? []).map((row) => ({
        ...row,
        amount: Number(row.amount),
      }))
    );
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}

export async function POST(request: NextRequest) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  try {
    const body = await request.json();
    const { title, category, amount, currency, notes, payment_date } = body;

    if (!title || String(title).trim() === "") {
      return Response.json({ error: "العنوان مطلوب" }, { status: 400 });
    }
    if (!category || !CATEGORIES.includes(category)) {
      return Response.json({ error: "التصنيف غير صالح" }, { status: 400 });
    }
    if (amount == null || Number(amount) <= 0) {
      return Response.json({ error: "المبلغ مطلوب" }, { status: 400 });
    }
    if (!currency || !["SYP", "USD"].includes(currency)) {
      return Response.json({ error: "عملة غير صالحة" }, { status: 400 });
    }

    const supabase = getAdminClient();
    const { data, error } = await supabase
      .from("expense_payments")
      .insert({
        title: String(title).trim(),
        category,
        amount: Number(amount),
        currency,
        notes: notes ? String(notes).trim() : null,
        payment_date: payment_date ?? new Date().toISOString(),
      })
      .select()
      .single();

    if (error) return serverError(error.message);

    return Response.json(
      { ...data, amount: Number(data.amount) },
      { status: 201 }
    );
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
