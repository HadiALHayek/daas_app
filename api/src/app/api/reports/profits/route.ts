import { NextRequest } from "next/server";
import { verifyAuth, unauthorized, serverError, badRequest } from "@/lib/auth";
import { getAdminClient } from "@/lib/supabase";

interface BillRow {
  id: string;
  currency: string;
  created_at: string;
  total: number;
  bill_payments: Array<{ amount: number }>;
}

interface ExpenseRow {
  amount: number;
  currency: string;
  payment_date: string;
}

interface PaymentRow {
  amount: number;
  payment_date: string;
  bills: { currency: string };
}

interface CurrencyTotals {
  incoming: number;
  collected: number;
  uncollected: number;
  outgoing: number;
  profit: number;
}

function currencyKey(currency: string): "SYP" | "USD" {
  return currency === "USD" ? "USD" : "SYP";
}

function sumBillSales(bills: BillRow[]) {
  const incoming = { SYP: 0, USD: 0 };
  const uncollected = { SYP: 0, USD: 0 };

  for (const bill of bills) {
    const key = currencyKey(bill.currency);
    const total = Number(bill.total || 0);
    const paid = (bill.bill_payments || []).reduce(
      (sum, p) => sum + Number(p.amount),
      0
    );

    incoming[key] += total;
    uncollected[key] += Math.max(0, total - paid);
  }
  return { incoming, uncollected };
}

function sumPayments(payments: PaymentRow[]) {
  const collected = { SYP: 0, USD: 0 };
  for (const p of payments) {
    const currency = p.bills?.currency || "SYP";
    const key = currencyKey(currency);
    collected[key] += Number(p.amount || 0);
  }
  return collected;
}

function sumExpenses(expenses: ExpenseRow[]) {
  const outgoing = { SYP: 0, USD: 0 };
  for (const expense of expenses) {
    const key = currencyKey(expense.currency);
    outgoing[key] += Number(expense.amount || 0);
  }
  return outgoing;
}

function buildCurrencyTotals(
  incoming: { SYP: number; USD: number },
  collected: { SYP: number; USD: number },
  uncollected: { SYP: number; USD: number },
  outgoing: { SYP: number; USD: number }
): { syp: CurrencyTotals; usd: CurrencyTotals } {
  return {
    syp: {
      incoming: incoming.SYP,
      collected: collected.SYP,
      uncollected: uncollected.SYP,
      outgoing: outgoing.SYP,
      profit: collected.SYP - outgoing.SYP,
    },
    usd: {
      incoming: incoming.USD,
      collected: collected.USD,
      uncollected: uncollected.USD,
      outgoing: outgoing.USD,
      profit: collected.USD - outgoing.USD,
    },
  };
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

    const startIso = startDate.toISOString();
    const endIso = endDate.toISOString();

    const [billsResult, expensesResult, paymentsResult] = await Promise.all([
      supabase
        .from("bills")
        .select("id, currency, created_at, total, bill_payments(amount)")
        .gte("created_at", startIso)
        .lt("created_at", endIso),
      supabase
        .from("expense_payments")
        .select("amount, currency, payment_date")
        .gte("payment_date", startIso)
        .lt("payment_date", endIso),
      supabase
        .from("bill_payments")
        .select("amount, payment_date, bills(currency)")
        .gte("payment_date", startIso)
        .lt("payment_date", endIso),
    ]);

    if (billsResult.error) return serverError(billsResult.error.message);
    if (expensesResult.error) return serverError(expensesResult.error.message);
    if (paymentsResult.error) return serverError(paymentsResult.error.message);

    const bills = (billsResult.data ?? []) as unknown as BillRow[];
    const expenses = (expensesResult.data ?? []) as ExpenseRow[];
    const payments = (paymentsResult.data ?? []) as unknown as PaymentRow[];

    const salesStats = sumBillSales(bills);
    const totals = buildCurrencyTotals(
      salesStats.incoming,
      sumPayments(payments),
      salesStats.uncollected,
      sumExpenses(expenses)
    );

    const breakdown: Array<{
      month: number;
      syp: CurrencyTotals;
      usd: CurrencyTotals;
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
        const monthPayments = payments.filter((p) => {
          const d = new Date(p.payment_date);
          return d >= mStart && d < mEnd;
        });

        const mSales = sumBillSales(monthBills);
        const monthTotals = buildCurrencyTotals(
          mSales.incoming,
          sumPayments(monthPayments),
          mSales.uncollected,
          sumExpenses(monthExpenses)
        );

        breakdown.push({
          month: m,
          ...monthTotals,
          bill_count: monthBills.length,
        });
      }
    }

    return Response.json({
      period,
      year,
      month: period === "monthly" ? month : undefined,
      ...totals,
      bill_count: bills.length,
      breakdown,
    });
  } catch (e) {
    return serverError(e instanceof Error ? e.message : "خطأ");
  }
}
