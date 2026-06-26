import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError } from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";

export async function GET(request: NextRequest) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  try {
    const supabase = getAdminClient();
    const { data, error } = await supabase
      .from("settings")
      .select("usd_to_syp, updated_at")
      .eq("id", 1)
      .single();

    if (error) return serverError(error.message);

    return Response.json({
      usd_to_syp: Number(data.usd_to_syp),
      updated_at: data.updated_at,
    });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}

export async function PUT(request: NextRequest) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  try {
    const body = await request.json();
    const { usd_to_syp } = body;

    if (usd_to_syp == null || Number(usd_to_syp) <= 0) {
      return Response.json({ error: "سعر صرف غير صالح" }, { status: 400 });
    }

    const supabase = getAdminClient();
    const { data, error } = await supabase
      .from("settings")
      .upsert({
        id: 1,
        usd_to_syp: Number(usd_to_syp),
        updated_at: new Date().toISOString(),
      })
      .select("usd_to_syp, updated_at")
      .single();

    if (error) return serverError(error.message);

    return Response.json({
      usd_to_syp: Number(data.usd_to_syp),
      updated_at: data.updated_at,
    });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
