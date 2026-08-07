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
    memo: typeof map.memo === "string" ? map.memo : null,
    referenceNumber:
      typeof map.referenceNumber === "string" ? map.referenceNumber : null,
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
  const match = memo.match(/\[?sb:(\d+)\]?/i);
  if (!match) return null;
  const id = Number(match[1]);
  return Number.isFinite(id) && id > 0 ? id : null;
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
