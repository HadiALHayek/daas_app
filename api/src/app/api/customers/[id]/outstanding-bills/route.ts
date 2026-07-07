import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError, badRequest } from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";
import { fetchOutstandingBills } from "@/lib/bill-snapshot";

type RouteContext = { params: Promise<{ id: string }> };

export async function GET(request: NextRequest, context: RouteContext) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  const { id: customerId } = await context.params;
  if (!customerId) return badRequest("معرف العميل مطلوب");

  try {
    const supabase = getAdminClient();
    const outstanding = await fetchOutstandingBills(supabase, customerId);
    return Response.json(outstanding);
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
