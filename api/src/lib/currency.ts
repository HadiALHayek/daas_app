export async function convertToBillCurrency(
  amount: number,
  fromCurrency: string,
  billCurrency: string,
  rate: number
): Promise<number> {
  if (fromCurrency === billCurrency) return amount;
  if (fromCurrency === "USD" && billCurrency === "SYP") return amount * rate;
  if (fromCurrency === "SYP" && billCurrency === "USD") return amount / rate;
  return amount;
}
