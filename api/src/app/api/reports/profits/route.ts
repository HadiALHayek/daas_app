import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError, badRequest } from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";

interface BillRow {
  id: string;
  currency: string;
  total: number;
  usd_to_syp_rate: number;
  created_at: string;
  bill_payments: Array<{ amount: number; usd_to_syp_rate?: number }>;
}

interface ExpenseRow {
  amount: number;
  currency: string;
  payment_date: string;
  usd_to_syp_rate?: number;
}

interface CurrencyTotals {
  incoming: number;
  collected: number;
  uncollected_usd: number;
  uncollected_syp: number;
  outgoing: number;
  profit: number;
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

    const supabase = getAdminClient();

    // Fetch current exchange rate for fallback
    const { data: settings } = await supabase
      .from("settings")
      .select("usd_to_syp")
      .eq("id", 1)
      .maybeSingle();
    const currentRate = Number(settings?.usd_to_syp || 15000);

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
          "id, currency, total, usd_to_syp_rate, created_at, bill_payments(amount, usd_to_syp_rate)"
        )
        .gte("created_at", startIso)
        .lt("created_at", endIso),
      supabase
        .from("expense_payments")
        .select("amount, currency, payment_date, usd_to_syp_rate")
        .gte("payment_date", startIso)
        .lt("payment_date", endIso),
    ]);

    if (billsResult.error) return serverError(billsResult.error.message);
    if (expensesResult.error) return serverError(expensesResult.error.message);

    const bills = (billsResult.data ?? []) as unknown as BillRow[];
    const expenses = (expensesResult.data ?? []) as unknown as ExpenseRow[];

    const calculateTotals = (
      periodBills: BillRow[],
      periodExpenses: ExpenseRow[]
    ): CurrencyTotals => {
      let incomingUsd = 0;
      let collectedUsd = 0;
      let uncollectedUsd = 0;
      let uncollectedSyp = 0;
      let outgoingUsd = 0;

      for (const bill of periodBills) {
        const billRate = Number(bill.usd_to_syp_rate || currentRate);
        const total = Number(bill.total);

        // Sales (Incoming) uses the bill's creation rate
        incomingUsd += bill.currency === "USD" ? total : total / billRate;

        let totalPaidInOriginalCurrency = 0;

        for (const p of bill.bill_payments || []) {
          const paymentAmount = Number(p.amount);
          const paymentRate = Number(p.usd_to_syp_rate || billRate);

          totalPaidInOriginalCurrency += paymentAmount;

          // Collection uses the historical rate of the payment day
          collectedUsd +=
            bill.currency === "USD" ? paymentAmount : paymentAmount / paymentRate;
        }

        const debt = Math.max(0, total - totalPaidInOriginalCurrency);
        if (bill.currency === "USD") {
          uncollectedUsd += debt;
        } else {
          uncollectedSyp += debt;
        }
      }

      for (const exp of periodExpenses) {
        const expRate = Number(exp.usd_to_syp_rate || currentRate);
        const amount = Number(exp.amount);
        outgoingUsd += exp.currency === "USD" ? amount : amount / expRate;
      }

      return {
        incoming: Number(incomingUsd.toFixed(2)),
        collected: Number(collectedUsd.toFixed(2)),
        uncollected_usd: Number(uncollectedUsd.toFixed(2)),
        uncollected_syp: Number(uncollectedSyp.toFixed(0)),
        outgoing: Number(outgoingUsd.toFixed(2)),
        profit: Number((collectedUsd - outgoingUsd).toFixed(2)),
      };
    };

    const totals = calculateTotals(bills, expenses);

    const breakdown: Array<{
      month: number;
      report: CurrencyTotals;
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

        breakdown.push({
          month: m,
          report: calculateTotals(monthBills, monthExpenses),
          bill_count: monthBills.length,
        });
      }
    }

    return Response.json({
      period,
      year,
      month: period === "monthly" ? month : undefined,
      report: totals,
      bill_count: bills.length,
      breakdown,
    });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
