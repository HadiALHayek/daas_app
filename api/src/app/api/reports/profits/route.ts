import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError, badRequest } from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";

interface BillRow {
  id: string;
  currency: string;
  usd_to_syp_rate: number;
  created_at: string;
  bill_items: Array<{
    total_sell: number;
    total_item_cost: number;
  }>;
}

function toSyp(amount: number, currency: string, rate: number): number {
  if (currency === "SYP") return amount;
  return amount * rate;
}

function aggregateBills(bills: BillRow[]) {
  let incoming = 0;
  let outgoing = 0;

  for (const bill of bills) {
    const rate = Number(bill.usd_to_syp_rate);
    for (const item of bill.bill_items ?? []) {
      incoming += toSyp(Number(item.total_sell), bill.currency, rate);
      outgoing += toSyp(Number(item.total_item_cost), bill.currency, rate);
    }
  }

  return { incoming, outgoing, profit: incoming - outgoing, bill_count: bills.length };
}

export async function GET(request: NextRequest) {
  const userId = await verifyAuth(request);
  if (!userId) return unauthorized();

  try {
    const { searchParams } = new URL(request.url);
    const period = searchParams.get("period");
    const year = parseInt(searchParams.get("year") ?? "", 10);
    const month = parseInt(searchParams.get("month") ?? "", 10);

    if (!period || !year) {
      return badRequest("period و year مطلوبان");
    }

    if (period === "monthly" && (!month || month < 1 || month > 12)) {
      return badRequest("month مطلوب للتقرير الشهري (1-12)");
    }

    const supabase = getAdminClient();

    const startDate =
      period === "monthly"
        ? new Date(year, month - 1, 1)
        : new Date(year, 0, 1);
    const endDate =
      period === "monthly"
        ? new Date(year, month, 1)
        : new Date(year + 1, 0, 1);

    const { data, error } = await supabase
      .from("bills")
      .select(
        `
        id,
        currency,
        usd_to_syp_rate,
        created_at,
        bill_items ( total_sell, total_item_cost )
      `
      )
      .gte("created_at", startDate.toISOString())
      .lt("created_at", endDate.toISOString());

    if (error) return serverError(error.message);

    const bills = (data ?? []) as BillRow[];
    const totals = aggregateBills(bills);

    const breakdown: Array<{
      month: number;
      incoming: number;
      outgoing: number;
      profit: number;
      bill_count: number;
    }> = [];

    if (period === "yearly") {
      for (let m = 1; m <= 12; m++) {
        const mStart = new Date(year, m - 1, 1);
        const mEnd = new Date(year, m, 1);
        const monthBills = bills.filter((b) => {
          const d = new Date(b.created_at);
          return d >= mStart && d < mEnd;
        });
        const monthTotals = aggregateBills(monthBills);
        breakdown.push({ month: m, ...monthTotals });
      }
    }

    return Response.json({
      period,
      year,
      month: period === "monthly" ? month : undefined,
      currency: "SYP",
      ...totals,
      breakdown,
    });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
