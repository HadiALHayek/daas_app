import { badRequest, notFound, serverError } from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";

export async function updateCustomerById(
  id: string,
  name: unknown,
  phone: unknown,
  address?: unknown
) {
  if (!id) return badRequest("معرف العميل مطلوب");

  if (!name || String(name).trim() === "") {
    return badRequest("اسم العميل مطلوب");
  }

  const supabase = getAdminClient();
  const { data, error } = await supabase
    .from("customers")
    .update({
      name: String(name).trim(),
      phone: phone ? String(phone).trim() : null,
      address: address ? String(address).trim() : null,
    })
    .eq("id", id)
    .select()
    .single();

  if (error) return serverError(error.message);
  if (!data) return notFound("العميل غير موجود");

  return Response.json(data);
}

export async function deleteCustomerById(id: string) {
  if (!id) return badRequest("معرف العميل مطلوب");

  const supabase = getAdminClient();

  const { data: bills, error: billsQueryError } = await supabase
    .from("bills")
    .select("id")
    .eq("customer_id", id);

  if (billsQueryError) return serverError(billsQueryError.message);

  if (bills?.length) {
    const billIds = bills.map((bill) => bill.id);
    const { error: billsDeleteError } = await supabase
      .from("bills")
      .delete()
      .in("id", billIds);

    if (billsDeleteError) return serverError(billsDeleteError.message);
  }

  const { error } = await supabase.from("customers").delete().eq("id", id);

  if (error) return serverError(error.message);

  return Response.json({ success: true });
}
