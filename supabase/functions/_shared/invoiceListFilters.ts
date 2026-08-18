export type InvoiceListFilterBody = {
  status?: string;
  paidOnDateRange?: [string, string];
  createdFrom?: string;
  createdTo?: string;
  includeOpen?: boolean;
  openOnly?: boolean;
  invoiceId?: number;
};

const OPEN_STATUSES = "UNPAID,PROCESSING,PENDING";

export function applyInvoiceListFilters(
  query: any,
  body: InvoiceListFilterBody,
) {
  const {
    status,
    paidOnDateRange,
    createdFrom,
    createdTo,
    includeOpen,
    openOnly,
    invoiceId,
  } = body;

  if (invoiceId) {
    query.eq("id", invoiceId);
    return query;
  }

  if (openOnly) {
    query.in("status", ["UNPAID", "PROCESSING", "PENDING"]);
    return query;
  }

  if (status === "PAID" && paidOnDateRange?.length === 2) {
    query
      .eq("status", "PAID")
      .gte("paidOnDate", paidOnDateRange[0])
      .lte("paidOnDate", paidOnDateRange[1]);
    return query;
  }

  if (status === "UNPAID" || status === "PROCESSING") {
    query.eq("status", status);
    return query;
  }

  if (status) {
    query.eq("status", status);
  }

  if (includeOpen && createdFrom && createdTo) {
    query.or(
      `and(created_at.gte."${createdFrom}",created_at.lt."${createdTo}"),status.in.(${OPEN_STATUSES})`,
    );
    return query;
  }

  if (createdFrom && createdTo) {
    query.gte("created_at", createdFrom).lt("created_at", createdTo);
    return query;
  }

  if (paidOnDateRange?.length === 2) {
    query
      .gte("paidOnDate", paidOnDateRange[0])
      .lte("paidOnDate", paidOnDateRange[1]);
    return query;
  }

  const oneYearAgo = new Date();
  oneYearAgo.setFullYear(oneYearAgo.getFullYear() - 1);
  query.gte("created_at", oneYearAgo.toISOString());
  return query;
}
