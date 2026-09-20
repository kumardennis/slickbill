import { InvoiceListFilterBody } from "./invoiceListFilters.ts";

function sumAmounts(rows: { amount?: number }[] | null | undefined): number {
  if (!rows?.length) return 0;
  return rows.reduce((sum, row) => sum + (Number(row.amount) || 0), 0);
}

export async function loadInvoiceListStats(
  supabase: any,
  privateUserId: number,
  side: "received" | "sent",
  body: InvoiceListFilterBody,
): Promise<{ openSum: number; paidSum: number }> {
  const select = side === "received"
    ? "amount, receivers!inner(privateUserId)"
    : "amount, senders!inner(privateUserId)";
  const userColumn = side === "received"
    ? "receivers.privateUserId"
    : "senders.privateUserId";

  const base = () =>
    supabase
      .from("digital_invoices")
      .select(select)
      .eq(userColumn, privateUserId)
      .eq("isObsolete", false);

  const openQuery = base().in("status", ["UNPAID", "PROCESSING", "PENDING"]);

  let paidQuery = base().eq("status", "PAID");
  if (!body.allTime) {
    if (body.paidOnDateRange?.length === 2) {
      paidQuery = paidQuery
        .gte("paidOnDate", body.paidOnDateRange[0])
        .lte("paidOnDate", body.paidOnDateRange[1]);
    } else if (body.createdFrom && body.createdTo) {
      paidQuery = paidQuery
        .gte("created_at", body.createdFrom)
        .lt("created_at", body.createdTo);
    }
  }

  const [{ data: openRows }, { data: paidRows }] = await Promise.all([
    openQuery,
    paidQuery,
  ]);

  return {
    openSum: sumAmounts(openRows),
    paidSum: sumAmounts(paidRows),
  };
}
