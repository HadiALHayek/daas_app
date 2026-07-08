import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError, badRequest } from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";

type RouteContext = { params: Promise<{ id: string }> };

export async function GET(request: NextRequest, context: RouteContext) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  const { id } = await context.params;

  try {
    const supabase = getAdminClient();
    const { data, error } = await supabase
      .from("employee_loans")
      .select("*")
      .eq("employee_id", id)
      .order("loan_date", { ascending: false });

    if (error) return serverError(error.message);

    return Response.json(
      (data ?? []).map((row) => ({ ...row, amount: Number(row.amount) }))
    );
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}

export async function POST(request: NextRequest, context: RouteContext) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  const { id } = await context.params;

  try {
    const body = await request.json();
    const { amount, note, loan_date } = body;

    if (amount == null || Number(amount) <= 0) {
      return badRequest("المبلغ مطلوب");
    }

    const supabase = getAdminClient();
    const { data, error } = await supabase
      .from("employee_loans")
      .insert({
        employee_id: id,
        amount: Number(amount),
        note: note ? String(note).trim() : null,
        loan_date: loan_date ?? new Date().toISOString(),
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
