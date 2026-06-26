import { NextRequest } from "next/server";
import { getAdminClient } from "./supabase";

export async function verifyAuth(request: NextRequest): Promise<string | null> {
  const authHeader = request.headers.get("authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return null;
  }
  const token = authHeader.slice(7);
  const supabase = getAdminClient();
  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data.user) {
    return null;
  }
  return data.user.id;
}

export function unauthorized() {
  return Response.json({ error: "غير مصرح" }, { status: 401 });
}

export function badRequest(message: string) {
  return Response.json({ error: message }, { status: 400 });
}

export function notFound(message = "غير موجود") {
  return Response.json({ error: message }, { status: 404 });
}

export function serverError(message = "خطأ في الخادم") {
  return Response.json({ error: message }, { status: 500 });
}
