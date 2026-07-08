import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError } from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";

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
