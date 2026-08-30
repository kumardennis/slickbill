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

const formatCounterpartName = (details: Record<string, any> | null) => {
  if (!details) return null;
  const company =
    typeof details.companyName === "string" ? details.companyName.trim() : "";
  if (company) return company;
  const name = typeof details.name === "string" ? details.name.trim() : "";
  if (name) return name;
  const first =
    typeof details.firstName === "string" ? details.firstName.trim() : "";
  const last =
    typeof details.lastName === "string" ? details.lastName.trim() : "";
  const combined = `${first} ${last}`.trim();
  return combined || null;
};

export const summarizeMoneriumOrder = (
  order: unknown,
): MoneriumOrderSummary => {
  const map = asRecord(order) ?? {};
  const meta = asRecord(map.meta) ?? {};
  const counterpart = asRecord(map.counterpart);
  const identifier = asRecord(counterpart?.identifier);
  const details = asRecord(counterpart?.details);

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
    counterpartIban:
      typeof identifier?.iban === "string" ? identifier.iban : null,
    counterpartName: formatCounterpartName(details),
    txHashes,
    raw: order,
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

export const normalizeIban = (value?: string | null): string | null => {
  if (!value || typeof value !== "string") return null;
  const cleaned = value.replace(/\s+/g, "").toUpperCase();
  return cleaned.length >= 15 ? cleaned : null;
};
