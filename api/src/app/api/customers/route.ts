import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError } from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";

export async function GET(request: NextRequest) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  try {
    const supabase = getAdminClient();
    const { data, error } = await supabase
      .from("customers")
      .select("*")
      .order("name", { ascending: true });

    if (error) return serverError(error.message);

    return Response.json(data ?? []);
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}

export async function POST(request: NextRequest) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  try {
    const body = await request.json();
    const { name, phone } = body;

    if (!name) {
      return Response.json({ error: "اسم العميل مطلوب" }, { status: 400 });
    }

    const supabase = getAdminClient();
    const { data, error } = await supabase
      .from("customers")
      .insert({ name, phone: phone ?? null })
      .select()
      .single();

    if (error) return serverError(error.message);

    return Response.json(data, { status: 201 });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
