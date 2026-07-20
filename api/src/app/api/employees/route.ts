import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError } from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";
import { upsertSalaryRate } from "@/lib/salary-data";

type WorkSessionRow = {
  id: string;
  start_at: string;
  end_at: string | null;
};

export async function GET(request: NextRequest) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  try {
    const supabase = getAdminClient();
    const { data, error } = await supabase
      .from("employees")
      .select("*, work_sessions(id, start_at, end_at)")
      .eq("active", true)
      .order("created_at", { ascending: true });

    if (error) return serverError(error.message);

    // Outstanding (unsettled) loans — cleared on salary payday, so the card
    // starts each new week at zero after payment.
    const { data: loans, error: loanError } = await supabase
      .from("employee_loans")
      .select("employee_id, amount")
      .is("settled_week_start", null);
    if (loanError) return serverError(loanError.message);

    const weekLoanByEmp = new Map<string, number>();
    for (const l of loans ?? []) {
      weekLoanByEmp.set(
        l.employee_id,
        (weekLoanByEmp.get(l.employee_id) ?? 0) + Number(l.amount)
      );
    }

    return Response.json(
      (data ?? []).map((row) => {
        const sessions = (row.work_sessions ?? []) as WorkSessionRow[];
        const open = sessions.find((s) => s.end_at == null) ?? null;
        return {
          id: row.id,
          name: row.name,
          weekly_salary: Number(row.weekly_salary),
          currency: row.currency,
          active: row.active,
          created_at: row.created_at,
          week_loans: weekLoanByEmp.get(row.id) ?? 0,
          active_session: open
            ? { id: open.id, start_at: open.start_at }
            : null,
        };
      })
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
    const { name, weekly_salary } = body;

    if (!name || String(name).trim() === "") {
      return Response.json({ error: "الاسم مطلوب" }, { status: 400 });
    }
    if (weekly_salary == null || Number(weekly_salary) < 0) {
      return Response.json({ error: "الراتب الأسبوعي مطلوب" }, { status: 400 });
    }

    const supabase = getAdminClient();
    const { data, error } = await supabase
      .from("employees")
      .insert({
        name: String(name).trim(),
        weekly_salary: Number(weekly_salary),
        currency: "SYP",
      })
      .select()
      .single();

    if (error) return serverError(error.message);

    // Seed salary history far in the past so every prior week uses this rate
    // until the admin changes it (then a new rate starts from the current week).
    try {
      await upsertSalaryRate(
        supabase,
        data.id,
        Number(data.weekly_salary),
        "2000-01-01"
      );
    } catch (e) {
      console.error("upsertSalaryRate on create failed", e);
    }

    return Response.json(
      {
        id: data.id,
        name: data.name,
        weekly_salary: Number(data.weekly_salary),
        currency: data.currency,
        active: data.active,
        created_at: data.created_at,
        active_session: null,
      },
      { status: 201 }
    );
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
