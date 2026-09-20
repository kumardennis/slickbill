import { InvoiceListFilterBody, sanitizedInvoiceSearch } from "./invoiceListFilters.ts";

export async function restrictQueryToSearchIds(
  supabase: any,
  query: any,
  body: InvoiceListFilterBody,
  side: "sent" | "received",
): Promise<{ query: any; empty: boolean }> {
  const q = sanitizedInvoiceSearch(body.search);
  if (!q) return { query, empty: false };

  const { data, error } = await supabase.rpc("search_my_digital_invoice_ids", {
    p_side: side,
    p_q: q,
  });

  if (error) {
    throw error;
  }

  const ids = (Array.isArray(data) ? data : [])
    .map((row: { id?: number }) => row?.id)
    .filter((id: unknown): id is number => typeof id === "number");

  if (ids.length === 0) {
    return { query, empty: true };
  }

  return { query: query.in("id", ids), empty: false };
}
