import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError } from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";

type RouteContext = { params: Promise<{ loanId: string }> };

export async function DELETE(request: NextRequest, context: RouteContext) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  const { loanId } = await context.params;

  try {
    const supabase = getAdminClient();
    const { error } = await supabase
      .from("employee_loans")
      .delete()
      .eq("id", loanId);

    if (error) return serverError(error.message);

    return Response.json({ success: true });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
