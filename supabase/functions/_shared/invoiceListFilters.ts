export type InvoiceListFilterBody = {
  status?: string;
  paidOnDateRange?: [string, string];
  createdFrom?: string;
  createdTo?: string;
  matchAnyDate?: boolean;
  openOnly?: boolean;
  invoiceId?: number;
  /** Skip date window entirely (status filter only, or no status = everything). */
  allTime?: boolean;
};

function monthDateOrFilter(
  createdFrom: string,
  createdTo: string,
  columns: string[],
) {
  return columns
    .map(
      (column) =>
        `and(${column}.gte."${createdFrom}",${column}.lt."${createdTo}")`,
    )
    .join(",");
}

export function applyInvoiceListFilters(
  query: any,
  body: InvoiceListFilterBody,
) {
  const {
    status,
    paidOnDateRange,
    createdFrom,
    createdTo,
    matchAnyDate,
    openOnly,
    invoiceId,
    allTime,
  } = body;

  if (invoiceId) {
    query.eq("id", invoiceId);
    return query;
  }

  if (openOnly) {
    query.in("status", ["UNPAID", "PROCESSING", "PENDING"]);
    return query;
  }

  if (allTime) {
    if (status === "PROCESSING") {
      query.in("status", ["PROCESSING", "PENDING"]);
    } else if (status) {
      query.eq("status", status);
    }
    return query;
  }

  if (status === "PAID" && paidOnDateRange?.length === 2) {
    query
      .eq("status", "PAID")
      .gte("paidOnDate", paidOnDateRange[0])
      .lte("paidOnDate", paidOnDateRange[1]);
    return query;
  }

  if (status) {
    query.eq("status", status);
  }

  if (matchAnyDate && createdFrom && createdTo) {
    const columns = status
      ? ["created_at", "deadline"]
      : ["created_at", "deadline", "paidOnDate"];
    query.or(monthDateOrFilter(createdFrom, createdTo, columns));
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
