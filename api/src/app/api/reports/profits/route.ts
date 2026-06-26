import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError, badRequest } from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";

interface BillRow {
  id: string;
  currency: string;
  usd_to_syp_rate: number;
  created_at: string;
  bill_items: Array<{ total_sell: number }>;
}

interface ExpenseRow {
  amount: number;
  currency: string;
  payment_date: string;
}

function toSyp(amount: number, currency: string, rate: number): number {
  if (currency === "SYP") return amount;
  return amount * rate;
}

function aggregateBills(bills: BillRow[]) {
  let incoming = 0;

  for (const bill of bills) {
    const rate = Number(bill.usd_to_syp_rate);
    for (const item of bill.bill_items ?? []) {
      incoming += toSyp(Number(item.total_sell), bill.currency, rate);
    }
  }

  return { incoming, bill_count: bills.length };
}

function aggregateExpenses(
  expenses: ExpenseRow[],
  defaultRate: number
) {
  let outgoing = 0;

  for (const expense of expenses) {
    outgoing += toSyp(Number(expense.amount), expense.currency, defaultRate);
  }

  return outgoing;
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

    const { data: settings } = await supabase
      .from("settings")
      .select("usd_to_syp")
      .eq("id", 1)
      .maybeSingle();

    const defaultRate = Number(settings?.usd_to_syp ?? 15000);

    const startDate =
      period === "monthly"
        ? new Date(year, month - 1, 1)
        : new Date(year, 0, 1);
    const endDate =
      period === "monthly"
        ? new Date(year, month, 1)
        : new Date(year + 1, 0, 1);

    const startIso = startDate.toISOString();
    const endIso = endDate.toISOString();

    const [billsResult, expensesResult] = await Promise.all([
      supabase
        .from("bills")
        .select(
          `
          id,
          currency,
          usd_to_syp_rate,
          created_at,
          bill_items ( total_sell )
        `
        )
        .gte("created_at", startIso)
        .lt("created_at", endIso),
      supabase
        .from("expense_payments")
        .select("amount, currency, payment_date")
        .gte("payment_date", startIso)
        .lt("payment_date", endIso),
    ]);

    if (billsResult.error) return serverError(billsResult.error.message);
    if (expensesResult.error) return serverError(expensesResult.error.message);

    const bills = (billsResult.data ?? []) as BillRow[];
    const expenses = (expensesResult.data ?? []) as ExpenseRow[];

    const billTotals = aggregateBills(bills);
    const outgoing = aggregateExpenses(expenses, defaultRate);
    const incoming = billTotals.incoming;
    const profit = incoming - outgoing;

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
        const monthExpenses = expenses.filter((e) => {
          const d = new Date(e.payment_date);
          return d >= mStart && d < mEnd;
        });
        const monthBillTotals = aggregateBills(monthBills);
        const monthOutgoing = aggregateExpenses(monthExpenses, defaultRate);
        const monthIncoming = monthBillTotals.incoming;
        breakdown.push({
          month: m,
          incoming: monthIncoming,
          outgoing: monthOutgoing,
          profit: monthIncoming - monthOutgoing,
          bill_count: monthBillTotals.bill_count,
        });
      }
    }

    return Response.json({
      period,
      year,
      month: period === "monthly" ? month : undefined,
      currency: "SYP",
      incoming,
      outgoing,
      profit,
      bill_count: billTotals.bill_count,
      breakdown,
    });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
