import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError } from "@/lib/auth";
import { deleteCustomerById, updateCustomerById } from "@/lib/customer-mutations";
import { getAdminClient } from "@/lib/supabase";

function customerIdFromRequest(request: NextRequest) {
  return new URL(request.url).searchParams.get("id");
}

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

export async function PUT(request: NextRequest) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  try {
    const body = await request.json();
    const id = customerIdFromRequest(request) ?? body.id;
    return updateCustomerById(id, body.name, body.phone);
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}

export async function DELETE(request: NextRequest) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  try {
    const id = customerIdFromRequest(request);
    if (id) return deleteCustomerById(id);

    const body = await request.json().catch(() => null);
    const bodyId = body?.id;
    if (typeof bodyId === "string" && bodyId) {
      return deleteCustomerById(bodyId);
    }

    return Response.json({ error: "معرف العميل مطلوب" }, { status: 400 });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
