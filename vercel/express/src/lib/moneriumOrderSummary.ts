export type MoneriumOrderSummary = {
  id: string | null;
  kind: string | null;
  state: string | null;
  amount: string | null;
  currency: string | null;
  memo: string | null;
  referenceNumber: string | null;
  address: string | null;
  counterpartIban: string | null;
  counterpartName: string | null;
  txHashes: string[];
  raw: unknown;
};

const asRecord = (value: unknown): Record<string, any> | null =>
  value && typeof value === "object" ? (value as Record<string, any>) : null;

export const readMoneriumOrdersArray = (payload: unknown): unknown[] => {
  if (Array.isArray(payload)) return payload;
  const map = asRecord(payload);
  if (!map) return [];
  for (const key of ["orders", "data", "items", "results"]) {
    if (Array.isArray(map[key])) return map[key];
  }
  // Single order object
  if (typeof map.id === "string") return [map];
  return [];
};

const firstNonEmptyString = (...values: unknown[]): string | null => {
  for (const value of values) {
    if (typeof value === "string" && value.trim()) return value.trim();
  }
  return null;
};

export const normalizeIban = (value?: string | null): string | null => {
  if (!value || typeof value !== "string") return null;
  const cleaned = value.replace(/\s+/g, "").toUpperCase();
  return cleaned.length >= 15 ? cleaned : null;
};

const unwrapOrderRecord = (order: unknown): Record<string, any> => {
  let map = asRecord(order);
  if (!map) return {};
  const nestedData = asRecord(map.data);
  if (nestedData && (nestedData.id || nestedData.counterpart)) {
    map = nestedData;
  }
  const nestedOrder = asRecord(map.order);
  if (nestedOrder && (nestedOrder.id || nestedOrder.counterpart)) {
    map = nestedOrder;
  }
  return map;
};

const formatPartyName = (party: Record<string, any> | null): string | null => {
  if (!party) return null;
  const details = asRecord(party.details) ?? party;
  return firstNonEmptyString(
    details.companyName,
    details.company,
    details.name,
    party.companyName,
    party.name,
    `${typeof details.firstName === "string" ? details.firstName : ""} ${
      typeof details.lastName === "string" ? details.lastName : ""
    }`.trim(),
    `${typeof party.firstName === "string" ? party.firstName : ""} ${
      typeof party.lastName === "string" ? party.lastName : ""
    }`.trim(),
  );
};

const extractCounterpartIban = (map: Record<string, any>): string | null => {
  const counterpart = asRecord(map.counterpart);
  const identifier = asRecord(counterpart?.identifier);
  const payer = asRecord(map.payer) ?? asRecord(map.debtor);
  const payerId = asRecord(payer?.identifier);
  const topIdentifier = asRecord(map.identifier);
  return normalizeIban(
    firstNonEmptyString(
      identifier?.iban,
      identifier?.account,
      counterpart?.iban,
      payerId?.iban,
      payerId?.account,
      payer?.iban,
      topIdentifier?.iban,
      topIdentifier?.account,
      map.iban,
      asRecord(map.meta)?.iban,
    ),
  );
};

const extractCounterpartName = (map: Record<string, any>): string | null => {
  if (typeof map.counterpart === "string") {
    return firstNonEmptyString(map.counterpart);
  }
  const counterpart = asRecord(map.counterpart);
  const payer = asRecord(map.payer);
  const debtor = asRecord(map.debtor);
  const originator = asRecord(map.originator);
  const sender = asRecord(map.sender);
  const meta = asRecord(map.meta);
  return (
    formatPartyName(counterpart) ||
    formatPartyName(payer) ||
    formatPartyName(debtor) ||
    formatPartyName(originator) ||
    formatPartyName(sender) ||
    formatPartyName(meta) ||
    firstNonEmptyString(
      map.counterpartName,
      map.payerName,
      map.debtorName,
      map.originatorName,
      meta?.counterpartName,
      meta?.payerName,
      meta?.debtorName,
    )
  );
};

export const orderMissingCounterpart = (
  order: Pick<MoneriumOrderSummary, "counterpartName" | "counterpartIban">,
): boolean => !order.counterpartName && !order.counterpartIban;

export const summarizeMoneriumOrder = (
  order: unknown,
): MoneriumOrderSummary => {
  const map = unwrapOrderRecord(order);
  const meta = asRecord(map.meta) ?? {};

  const txHashesRaw = meta.txHashes ?? map.txHashes ?? map.txHash;
  const txHashes = Array.isArray(txHashesRaw)
    ? txHashesRaw.map((v) => String(v))
    : typeof txHashesRaw === "string" && txHashesRaw.trim()
      ? [txHashesRaw.trim()]
      : [];

  return {
    id: typeof map.id === "string" ? map.id : null,
    kind: typeof map.kind === "string" ? map.kind : null,
    state: typeof map.state === "string" ? map.state : null,
    amount: map.amount != null ? String(map.amount) : null,
    currency: typeof map.currency === "string" ? map.currency : null,
    memo: firstNonEmptyString(
      map.memo,
      meta.memo,
      map.comment,
      map.narrative,
      map.remittanceInformation,
    ),
    referenceNumber: firstNonEmptyString(
      map.referenceNumber,
      map.reference,
      map.ref,
      map.endToEndId,
      meta.referenceNumber,
      meta.reference,
    ),
    address: typeof map.address === "string" ? map.address : null,
    counterpartIban: extractCounterpartIban(map),
    counterpartName: extractCounterpartName(map),
    txHashes,
    raw: Object.keys(map).length > 0 ? map : order,
  };
};

export const parseSbInvoiceIdFromMemo = (memo?: string | null): number | null => {
  if (!memo || typeof memo !== "string") return null;
  const tagged = memo.match(/\[sb:(\d+)\]/i) ?? memo.match(/\bsb:(\d+)\b/i);
  if (tagged) {
    const id = Number(tagged[1]);
    return Number.isFinite(id) && id > 0 ? id : null;
  }
  const compact = memo.trim().match(/^sb(\d+)$/i);
  if (compact) {
    const id = Number(compact[1]);
    return Number.isFinite(id) && id > 0 ? id : null;
  }
  return null;
};

/** In-platform marker only (`[sb:123]` / `sb123`). Not a user invoice number. */
export const parseSbInvoiceIdFromOrder = (
  order: Pick<MoneriumOrderSummary, "memo" | "referenceNumber" | "raw">,
): number | null => {
  const fromMemo = parseSbInvoiceIdFromMemo(order.memo);
  if (fromMemo) return fromMemo;
  const fromRef = parseSbInvoiceIdFromMemo(order.referenceNumber);
  if (fromRef) return fromRef;

  const map = asRecord(order.raw);
  if (!map) return null;
  const meta = asRecord(map.meta) ?? {};
  return (
    parseSbInvoiceIdFromMemo(
      firstNonEmptyString(
        map.memo,
        meta.memo,
        map.comment,
        map.narrative,
        map.referenceNumber,
        map.reference,
        meta.referenceNumber,
      ),
    ) ?? null
  );
};

export const amountsEqual2dp = (
  a?: string | number | null,
  b?: string | number | null,
): boolean => {
  if (a == null || b == null) return false;
  const na = Number(a);
  const nb = Number(b);
  if (!Number.isFinite(na) || !Number.isFinite(nb)) return false;
  return Math.round(na * 100) === Math.round(nb * 100);
};
