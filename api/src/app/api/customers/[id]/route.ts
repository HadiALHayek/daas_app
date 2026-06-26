import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError } from "@/lib/auth";
import { deleteCustomerById, updateCustomerById } from "@/lib/customer-mutations";

type RouteContext = { params: Promise<{ id: string }> };

export async function PUT(request: NextRequest, context: RouteContext) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  const { id } = await context.params;

  try {
    const body = await request.json();
    return updateCustomerById(id, body.name, body.phone);
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}

export async function DELETE(request: NextRequest, context: RouteContext) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  const { id } = await context.params;

  try {
    return deleteCustomerById(id);
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
