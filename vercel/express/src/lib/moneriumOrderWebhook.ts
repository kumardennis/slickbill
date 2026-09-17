import crypto from "node:crypto";
import { getSupabaseAdmin } from "./supabaseAdmin.js";
import {
  parseSbInvoiceIdFromOrder,
  readMoneriumOrdersArray,
  summarizeMoneriumOrder,
  type MoneriumOrderSummary,
} from "./moneriumOrderSummary.js";
import { notifyMoneriumFundsArrived } from "./notifyUser.js";

const ensuredAt = new Map<string, number>();
const ENSURE_TTL_MS = 6 * 60 * 60 * 1000;

const moneriumBaseUrl = () =>
  (process.env.MONERIUM_BASE_URL?.trim() || "https://api.monerium.app").replace(
    /\/$/,
    "",
  );

export const moneriumWebhookSecret = (): string => {
  const explicit = process.env.MONERIUM_WEBHOOK_SECRET?.trim();
  if (explicit) return explicit;
  const seed =
    process.env.MONERIUM_STATE_SECRET?.trim() || "slickbills-monerium-webhook";
  return `whsec_${Buffer.from(seed, "utf8").toString("base64")}`;
};

export const moneriumWebhookUrl = (): string | null => {
  const origin = process.env.PUBLIC_SERVER_URL?.trim();
  if (!origin) return null;
  return `${origin.replace(/\/$/, "")}/monerium/webhooks`;
};

const hmacKey = (secret: string): Buffer =>
  Buffer.from(secret.replace(/^whsec_/, ""), "base64");

export const verifyMoneriumWebhookSignature = (params: {
  rawBody: string;
  webhookId?: string;
  webhookTimestamp?: string;
  signature?: string;
}): boolean => {
  const id = params.webhookId?.trim() ?? "";
  const timestamp = params.webhookTimestamp?.trim() ?? "";
  const signature = params.signature?.trim() ?? "";
  if (!id || !timestamp || !signature) return false;

  const expected = crypto
    .createHmac("sha256", hmacKey(moneriumWebhookSecret()))
    .update(`${id}.${timestamp}.${params.rawBody}`)
    .digest("base64");
  const expectedHeader = `v1,${expected}`;
  const candidates = signature.split(/\s+/).map((part) => part.trim());
  return candidates.some((part) => timingSafeEqualString(part, expectedHeader));
};

const timingSafeEqualString = (a: string, b: string): boolean => {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  if (left.length !== right.length) return false;
  return crypto.timingSafeEqual(left, right);
};

const notifiedTable = () => {
  const supabase = getSupabaseAdmin();
  if (!supabase) return null;
  return supabase.from("monerium_notified_orders") as any;
};

/** Returns true when this caller won the notify slot. */
export const claimNotifiedOrder = async (
  orderId: string,
  privateUserId?: string,
  kind?: string,
): Promise<boolean> => {
  const id = orderId.trim();
  if (!id) return false;
  const table = notifiedTable();
  if (!table) return true;

  const { error } = await table.insert({
    orderId: id,
    privateUserId: privateUserId ?? null,
    kind: kind ?? null,
  });

  if (!error) return true;
  if (error.code === "23505") return false;
  console.warn("⚠️ monerium_notified_orders insert failed", error.message);
  return true;
};

const listWebhookUrls = (payload: unknown): string[] => {
  const rows = Array.isArray(payload)
    ? payload
    : payload && typeof payload === "object"
      ? ((payload as Record<string, unknown>).subscriptions as unknown[]) ??
        ((payload as Record<string, unknown>).webhooks as unknown[]) ??
        ((payload as Record<string, unknown>).data as unknown[]) ??
        []
      : [];
  if (!Array.isArray(rows)) return [];
  return rows
    .map((row) => {
      if (!row || typeof row !== "object") return "";
      const url = (row as Record<string, unknown>).url;
      return typeof url === "string" ? url.trim() : "";
    })
    .filter(Boolean);
};

const moneriumFetch = async (params: {
  accessToken: string;
  tokenType?: string;
  method: string;
  path: string;
  body?: unknown;
}): Promise<{ ok: boolean; status: number; data: unknown }> => {
  const response = await fetch(`${moneriumBaseUrl()}${params.path}`, {
    method: params.method,
    headers: {
      Authorization: `${params.tokenType || "Bearer"} ${params.accessToken}`,
      Accept: "application/vnd.monerium.api-v2+json",
      "Content-Type": "application/json",
    },
    ...(params.body !== undefined ? { body: JSON.stringify(params.body) } : {}),
  });
  const text = await response.text();
  let data: unknown = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = { raw: text };
  }
  return { ok: response.ok, status: response.status, data };
};

export const ensureMoneriumOrderWebhook = async (params: {
  privateUserId: string;
  accessToken?: string | null;
  tokenType?: string | null;
}): Promise<{ ok: boolean; created?: boolean; detail?: string }> => {
  const userId = params.privateUserId.trim();
  const accessToken = params.accessToken?.trim() ?? "";
  const url = moneriumWebhookUrl();
  if (!userId || !accessToken) {
    return { ok: false, detail: "missing_token" };
  }
  if (!url) {
    return { ok: false, detail: "PUBLIC_SERVER_URL missing" };
  }

  const last = ensuredAt.get(userId) ?? 0;
  if (Date.now() - last < ENSURE_TTL_MS) {
    return { ok: true, detail: "cached" };
  }

  const listed = await moneriumFetch({
    accessToken,
    tokenType: params.tokenType ?? undefined,
    method: "GET",
    path: "/webhooks",
  });
  if (listed.ok) {
    const urls = listWebhookUrls(listed.data);
    if (urls.some((existing) => existing.replace(/\/$/, "") === url.replace(/\/$/, ""))) {
      ensuredAt.set(userId, Date.now());
      return { ok: true, created: false, detail: "already_registered" };
    }
  }

  const created = await moneriumFetch({
    accessToken,
    tokenType: params.tokenType ?? undefined,
    method: "POST",
    path: "/webhooks",
    body: {
      url,
      secret: moneriumWebhookSecret(),
      types: ["order.created", "order.updated"],
    },
  });

  if (!created.ok) {
    console.warn("⚠️ Monerium webhook subscribe failed", {
      privateUserId: userId,
      status: created.status,
      data: created.data,
    });
    return { ok: false, detail: `http_${created.status}` };
  }

  ensuredAt.set(userId, Date.now());
  console.log("ℹ️ Subscribed Monerium order webhook", { privateUserId: userId, url });
  return { ok: true, created: true };
};

export const listRecentProcessedIssues = async (params: {
  accessToken: string;
  tokenType?: string | null;
}): Promise<ReturnType<typeof summarizeMoneriumOrder>[]> => {
  const listed = await moneriumFetch({
    accessToken: params.accessToken,
    tokenType: params.tokenType ?? undefined,
    method: "GET",
    path: "/orders",
  });
  if (!listed.ok) return [];
  const cutoff = Date.now() - 48 * 60 * 60 * 1000;
  return readMoneriumOrdersArray(listed.data)
    .map(summarizeMoneriumOrder)
    .filter((order) => {
      if ((order.kind ?? "").toLowerCase() !== "issue") return false;
      if ((order.state ?? "").toLowerCase() !== "processed") return false;
      const raw = order.raw && typeof order.raw === "object"
        ? (order.raw as Record<string, unknown>)
        : {};
      const meta =
        raw.meta && typeof raw.meta === "object"
          ? (raw.meta as Record<string, unknown>)
          : {};
      const stamped = [raw.updatedAt, raw.createdAt, raw.date, meta.processedAt]
        .map((value) => (typeof value === "string" ? Date.parse(value) : NaN))
        .find((value) => Number.isFinite(value));
      if (stamped != null && stamped < cutoff) return false;
      return true;
    })
    .slice(0, 20);
};

export const notifyProcessedIssueIfNeeded = async (params: {
  privateUserId: string;
  order: MoneriumOrderSummary;
}): Promise<{ notified: boolean; detail?: string }> => {
  const { order, privateUserId } = params;
  if ((order.kind ?? "").toLowerCase() !== "issue") {
    return { notified: false, detail: "not_issue" };
  }
  if ((order.state ?? "").toLowerCase() !== "processed") {
    return { notified: false, detail: "not_processed" };
  }
  if (parseSbInvoiceIdFromOrder(order)) {
    return { notified: false, detail: "invoice_marker" };
  }
  const orderId = order.id?.trim();
  if (!orderId) {
    return { notified: false, detail: "missing_order_id" };
  }
  const claimed = await claimNotifiedOrder(orderId, privateUserId, "issue");
  if (!claimed) {
    return { notified: false, detail: "already_notified" };
  }
  const result = await notifyMoneriumFundsArrived({
    privateUserId,
    txHash: order.txHashes[0] ?? null,
    amountHint: order.amount,
    orderId,
  });
  console.log("ℹ️ Incoming issue notification", {
    privateUserId,
    orderId,
    result,
  });
  return { notified: result.ok, detail: result.detail };
};

export const backfillRecentIncomingIssues = async (params: {
  privateUserId: string;
  accessToken: string;
  tokenType?: string | null;
}): Promise<{ notified: number }> => {
  const orders = await listRecentProcessedIssues({
    accessToken: params.accessToken,
    tokenType: params.tokenType,
  });
  let notified = 0;
  for (const order of orders) {
    const result = await notifyProcessedIssueIfNeeded({
      privateUserId: params.privateUserId,
      order,
    });
    if (result.notified) notified += 1;
  }
  return { notified };
};

