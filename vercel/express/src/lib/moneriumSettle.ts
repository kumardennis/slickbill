import { getSupabaseAdmin } from "./supabaseAdmin.js";
import { notifyUserViaSupabase } from "./notifyUser.js";
import {
  amountsEqual2dp,
  normalizeIban,
  parseSbInvoiceIdFromOrder,
  summarizeMoneriumOrder,
  type MoneriumOrderSummary,
} from "./moneriumOrderSummary.js";

export type SettleResult = {
  matched: boolean;
  path: "private" | "public" | "none" | "rejected";
  invoiceId: number | null;
  table: "digital_invoices" | "public_digital_invoices" | null;
  alreadyPaid: boolean;
  externalPaymentCount: number | null;
  notified: boolean;
  detail?: string;
};

type PrivateInvoiceRow = {
  id: number;
  status: string | null;
  amount: number | null;
  description?: string | null;
  referenceNo: string | null;
  senderIban: string | null;
  moneriumOrderId: string | null;
  senderPrivateUserId: number | string | null;
  receiverPrivateUserId: number | string | null;
  data: unknown;
};

type PublicInvoiceRow = {
  id: number;
  status: string | null;
  amount: number | null;
  description?: string | null;
  referenceNo: string | null;
  senderIban: string | null;
  senderPrivateUserId: number | string | null;
  externalPaymentCount: number | null;
  data: unknown;
  paidOnDate: string | null;
};

/** Bank remittance rarely keeps `[sb:id]`. Compare free-text description only. */
export const normalizePaymentDescription = (raw?: string | null): string => {
  if (!raw || typeof raw !== "string") return "";
  return raw
    .replace(/\[sb:\d+\]/gi, " ")
    .replace(/\bsb:\d+\b/gi, " ")
    .toLowerCase()
    .replace(/\s+/g, " ")
    .trim();
};

/**
 * True when bank/Monerium remittance matches invoice description (without sb tag).
 * Allows either side to be truncated.
 */
export const remittanceMatchesDescription = (
  remittance?: string | null,
  description?: string | null,
): boolean => {
  const a = normalizePaymentDescription(remittance);
  const b = normalizePaymentDescription(description);
  if (a.length < 2 || b.length < 2) return false;
  return a === b || a.includes(b) || b.includes(a);
};

const OPEN_STATUSES = new Set(["UNPAID", "PROCESSING", "PENDING"]);

const todayYmd = () => new Date().toISOString().slice(0, 10);

const normalizeStatus = (value?: string | null) =>
  (value ?? "").trim().toUpperCase();

const asNumberId = (value: unknown): number | null => {
  const n = typeof value === "number" ? value : Number(value);
  return Number.isFinite(n) && n > 0 ? n : null;
};

const invoicesTable = () => {
  const supabase = getSupabaseAdmin();
  if (!supabase) return null;
  return supabase.from("digital_invoices") as any;
};

const publicInvoicesTable = () => {
  const supabase = getSupabaseAdmin();
  if (!supabase) return null;
  return supabase.from("public_digital_invoices") as any;
};

const privateUsersTable = () => {
  const supabase = getSupabaseAdmin();
  if (!supabase) return null;
  return supabase.from("private_users") as any;
};

const resolveAppUserId = async (
  privateUserId: number | string | null | undefined,
): Promise<number | null> => {
  const table = privateUsersTable();
  const id = asNumberId(privateUserId);
  if (!table || !id) return null;
  const { data, error } = await table
    .select("userId")
    .eq("id", id)
    .maybeSingle();
  if (error || data?.userId == null) return null;
  return Number(data.userId);
};

const notifyPaid = async (params: {
  ownerPrivateUserId: number | string | null | undefined;
  invoiceId: number;
  payerHint?: string | null;
}) => {
  const appUserId = await resolveAppUserId(params.ownerPrivateUserId);
  if (!appUserId) {
    return false;
  }
  const payer =
    params.payerHint && params.payerHint.trim().length > 0
      ? params.payerHint.trim()
      : null;
  const result = await notifyUserViaSupabase({
    userId: appUserId,
    type: "SLICKBILL_PAID",
    title: "Slickbill Paid",
    body: payer
      ? `${payer} paid your slickbill`
      : "You got money in Slickbills.",
    data: { invoiceId: params.invoiceId },
  });
  return result.ok;
};

/** Notify the payer (invoice receiver) that their payment succeeded. */
const notifyPayerPaymentSuccess = async (params: {
  payerPrivateUserId: number | string | null | undefined;
  invoiceId: number;
}) => {
  const appUserId = await resolveAppUserId(params.payerPrivateUserId);
  const targetUserId = appUserId ?? asNumberId(params.payerPrivateUserId);
  if (!targetUserId) {
    console.warn("⚠️ Payer success notify skipped: no app userId", {
      invoiceId: params.invoiceId,
      payerPrivateUserId: params.payerPrivateUserId ?? null,
    });
    return false;
  }
  const result = await notifyUserViaSupabase({
    userId: targetUserId,
    type: "SLICKBILL_PAYMENT_SUCCESS",
    title: "Payment successful",
    body: "Your slickbill payment went through.",
    data: { invoiceId: params.invoiceId },
  });
  if (!result.ok) {
    console.warn("⚠️ Payer success FCM failed", {
      invoiceId: params.invoiceId,
      appUserId,
      detail: result.detail,
    });
  }
  return result.ok;
};

const findPrivatesByOrderId = async (
  orderId: string,
): Promise<PrivateInvoiceRow[]> => {
  const table = invoicesTable();
  if (!table || !orderId.trim()) return [];
  const { data, error } = await table
    .select(
      "id, status, amount, referenceNo, senderIban, moneriumOrderId, senderPrivateUserId, receiverPrivateUserId, data",
    )
    .eq("moneriumOrderId", orderId.trim())
    .limit(50);
  if (error || !Array.isArray(data)) return [];
  return data as PrivateInvoiceRow[];
};

const findPrivateByOrderId = async (
  orderId: string,
): Promise<PrivateInvoiceRow | null> => {
  const rows = await findPrivatesByOrderId(orderId);
  return rows[0] ?? null;
};

const invoiceAmountSum = (rows: PrivateInvoiceRow[]): number =>
  rows.reduce((sum, row) => sum + (Number(row.amount) || 0), 0);

const findPrivateById = async (
  id: number,
): Promise<PrivateInvoiceRow | null> => {
  const table = invoicesTable();
  if (!table) return null;
  const { data, error } = await table
    .select(
      "id, status, amount, referenceNo, senderIban, moneriumOrderId, senderPrivateUserId, receiverPrivateUserId, data",
    )
    .eq("id", id)
    .maybeSingle();
  if (error || !data) return null;
  return data as PrivateInvoiceRow;
};

const findPublicById = async (id: number): Promise<PublicInvoiceRow | null> => {
  const table = publicInvoicesTable();
  if (!table) return null;
  const { data, error } = await table
    .select(
      "id, status, amount, referenceNo, senderIban, senderPrivateUserId, externalPaymentCount, data, paidOnDate",
    )
    .eq("id", id)
    .maybeSingle();
  if (error || !data) return null;
  return data as PublicInvoiceRow;
};

const findByReference = async (
  referenceNo: string,
  preferPrivateUserId?: string | null,
): Promise<
  | { table: "digital_invoices"; row: PrivateInvoiceRow }
  | { table: "public_digital_invoices"; row: PublicInvoiceRow }
  | null
> => {
  const ref = referenceNo.trim();
  if (!ref) return null;

  const privateTable = invoicesTable();
  if (privateTable) {
    let query = privateTable
      .select(
        "id, status, amount, referenceNo, senderIban, moneriumOrderId, senderPrivateUserId, receiverPrivateUserId, data",
      )
      .eq("referenceNo", ref)
      .in("status", Array.from(OPEN_STATUSES));

    const prefer = asNumberId(preferPrivateUserId);
    if (prefer) {
      query = query.or(
        `senderPrivateUserId.eq.${prefer},receiverPrivateUserId.eq.${prefer}`,
      );
    }

    const { data, error } = await query.limit(2);
    if (!error && Array.isArray(data) && data.length === 1) {
      return { table: "digital_invoices", row: data[0] as PrivateInvoiceRow };
    }
    if (!error && Array.isArray(data) && data.length > 1 && !prefer) {
      // ambiguous — skip
    } else if (!error && Array.isArray(data) && data.length === 0 && prefer) {
      // retry without prefer filter
      const { data: all } = await privateTable
        .select(
          "id, status, amount, referenceNo, senderIban, moneriumOrderId, senderPrivateUserId, receiverPrivateUserId, data",
        )
        .eq("referenceNo", ref)
        .in("status", Array.from(OPEN_STATUSES))
        .limit(2);
      if (Array.isArray(all) && all.length === 1) {
        return { table: "digital_invoices", row: all[0] as PrivateInvoiceRow };
      }
    }
  }

  const publicTable = publicInvoicesTable();
  if (publicTable) {
    let query = publicTable
      .select(
        "id, status, amount, referenceNo, senderIban, senderPrivateUserId, externalPaymentCount, data, paidOnDate",
      )
      .eq("referenceNo", ref)
      .in("status", Array.from(OPEN_STATUSES));

    const prefer = asNumberId(preferPrivateUserId);
    if (prefer) {
      query = query.eq("senderPrivateUserId", prefer);
    }

    const { data, error } = await query.limit(2);
    if (!error && Array.isArray(data) && data.length === 1) {
      return {
        table: "public_digital_invoices",
        row: data[0] as PublicInvoiceRow,
      };
    }
    if ((!data || data.length === 0) && prefer) {
      const { data: all } = await publicTable
        .select(
          "id, status, amount, referenceNo, senderIban, senderPrivateUserId, externalPaymentCount, data, paidOnDate",
        )
        .eq("referenceNo", ref)
        .in("status", Array.from(OPEN_STATUSES))
        .limit(2);
      if (Array.isArray(all) && all.length === 1) {
        return {
          table: "public_digital_invoices",
          row: all[0] as PublicInvoiceRow,
        };
      }
    }
  }

  return null;
};

const findByAmountAndIban = async (
  amount: string | null,
  iban: string | null,
  preferPrivateUserId?: string | null,
): Promise<
  | { table: "digital_invoices"; row: PrivateInvoiceRow }
  | { table: "public_digital_invoices"; row: PublicInvoiceRow }
  | null
> => {
  const normalizedIban = normalizeIban(iban);
  if (!amount || !normalizedIban) return null;

  const candidates: Array<
    | { table: "digital_invoices"; row: PrivateInvoiceRow }
    | { table: "public_digital_invoices"; row: PublicInvoiceRow }
  > = [];

  const privateTable = invoicesTable();
  if (privateTable) {
    const { data } = await privateTable
      .select(
        "id, status, amount, referenceNo, senderIban, moneriumOrderId, senderPrivateUserId, receiverPrivateUserId, data",
      )
      .in("status", Array.from(OPEN_STATUSES))
      .limit(50);
    for (const row of (data ?? []) as PrivateInvoiceRow[]) {
      if ((row.moneriumOrderId ?? "").trim()) continue;
      if (
        amountsEqual2dp(row.amount, amount) &&
        normalizeIban(row.senderIban) === normalizedIban
      ) {
        candidates.push({ table: "digital_invoices", row });
      }
    }
  }

  const publicTable = publicInvoicesTable();
  if (publicTable) {
    const { data } = await publicTable
      .select(
        "id, status, amount, referenceNo, senderIban, senderPrivateUserId, externalPaymentCount, data, paidOnDate",
      )
      .in("status", Array.from(OPEN_STATUSES))
      .limit(50);
    for (const row of (data ?? []) as PublicInvoiceRow[]) {
      if (
        amountsEqual2dp(row.amount, amount) &&
        normalizeIban(row.senderIban) === normalizedIban
      ) {
        candidates.push({ table: "public_digital_invoices", row });
      }
    }
  }

  const prefer = asNumberId(preferPrivateUserId);
  const scoped = prefer
    ? candidates.filter((c) => {
        if (c.table === "digital_invoices") {
          return (
            asNumberId(c.row.senderPrivateUserId) === prefer ||
            asNumberId(c.row.receiverPrivateUserId) === prefer
          );
        }
        return asNumberId(c.row.senderPrivateUserId) === prefer;
      })
    : candidates;

  const pool = scoped.length > 0 ? scoped : candidates;
  if (pool.length !== 1) return null;
  return pool[0];
};

const claimsTable = () => {
  const supabase = getSupabaseAdmin();
  if (!supabase) return null;
  return supabase.from("public_invoice_claims") as any;
};

type PublicPayerSnapshot = {
  iban?: string | null;
  name?: string | null;
  moneriumOrderId?: string | null;
  source?: string;
  /** Stable id so webhook retries don't double-count (order id or claimed:digitalId). */
  paymentKey: string;
};

/**
 * Single place that increments public_digital_invoices.externalPaymentCount.
 * Does not change public status — claims/payments are tracked via counters.
 */
const recordPublicPayment = async (params: {
  publicId: number;
  payer: PublicPayerSnapshot;
}): Promise<{ count: number; recorded: boolean; detail?: string }> => {
  const publicTable = publicInvoicesTable();
  if (!publicTable) {
    return { count: 0, recorded: false, detail: "supabase_missing" };
  }

  const publicRow = await findPublicById(params.publicId);
  if (!publicRow) {
    return { count: 0, recorded: false, detail: "public_not_found" };
  }

  const existingData =
    publicRow.data && typeof publicRow.data === "object"
      ? { ...(publicRow.data as Record<string, unknown>) }
      : {};

  const settledKeys = Array.isArray(existingData.settledPaymentKeys)
    ? (existingData.settledPaymentKeys as unknown[]).map(String)
    : [];

  if (settledKeys.includes(params.payer.paymentKey)) {
    return {
      count: publicRow.externalPaymentCount ?? 0,
      recorded: false,
      detail: "duplicate_payment",
    };
  }

  const nextCount = (publicRow.externalPaymentCount ?? 0) + 1;
  settledKeys.push(params.payer.paymentKey);
  existingData.settledPaymentKeys = settledKeys;
  existingData.lastExternalPayer = {
    iban: params.payer.iban ?? null,
    name: params.payer.name ?? null,
    moneriumOrderId: params.payer.moneriumOrderId ?? null,
    paidAt: new Date().toISOString(),
    source: params.payer.source ?? "external",
    paymentKey: params.payer.paymentKey,
  };

  const { error } = await publicTable
    .update({
      externalPaymentCount: nextCount,
      data: existingData,
    })
    .eq("id", params.publicId);

  if (error) {
    console.error("❌ Failed to record public payment", {
      publicId: params.publicId,
      message: error.message,
    });
    return {
      count: publicRow.externalPaymentCount ?? 0,
      recorded: false,
      detail: error.message,
    };
  }

  console.log("💾 public payment recorded", {
    publicId: params.publicId,
    externalPaymentCount: nextCount,
    paymentKey: params.payer.paymentKey,
    source: params.payer.source ?? "external",
  });

  return { count: nextCount, recorded: true };
};

const resolveClaimerDisplayName = async (
  privateUserId?: number | string | null,
): Promise<string | null> => {
  const payerId = asNumberId(privateUserId);
  const users = privateUsersTable();
  if (!users || !payerId) return null;
  const { data: userRow } = await users
    .select("firstName, lastName")
    .eq("id", payerId)
    .maybeSingle();
  if (!userRow) return null;
  const name = `${userRow.firstName ?? ""} ${userRow.lastName ?? ""}`.trim();
  return name || null;
};

/**
 * After a private invoice is newly PAID, if it came from a public claim,
 * bump the parent public payment count (same helper as external).
 */
const recordPublicPaymentForClaimedInvoice = async (params: {
  digitalInvoiceId: number;
  order: MoneriumOrderSummary;
  payerPrivateUserId?: number | string | null;
}): Promise<number | null> => {
  const claims = claimsTable();
  if (!claims) return null;

  const { data: claim, error: claimError } = await claims
    .select("public_invoice_id, claimed_by_user_id")
    .eq("digital_invoice_id", params.digitalInvoiceId)
    .maybeSingle();

  if (claimError || !claim?.public_invoice_id) {
    return null;
  }

  const publicId = asNumberId(claim.public_invoice_id);
  if (!publicId) return null;

  const payerName = await resolveClaimerDisplayName(
    params.payerPrivateUserId ?? claim.claimed_by_user_id,
  );

  const paymentKey =
    params.order.id?.trim() || `claimed:${params.digitalInvoiceId}`;

  const result = await recordPublicPayment({
    publicId,
    payer: {
      iban: null,
      name: payerName,
      moneriumOrderId: params.order.id,
      source: "claimed_slickbills",
      paymentKey,
    },
  });

  return result.count;
};

/** Notify payer at most once per invoice (not per Monerium order id). */
const notifyPayerOnceForOrder = async (params: {
  row: PrivateInvoiceRow;
  order: MoneriumOrderSummary;
}): Promise<boolean> => {
  const existingData =
    params.row.data && typeof params.row.data === "object"
      ? { ...(params.row.data as Record<string, unknown>) }
      : {};

  // Burn (payer) + issue (payee) are different order ids; Statements reconcile
  // also re-settles. One success push per invoice.
  if (existingData.payerSuccessNotified === true) {
    return false;
  }

  const orderKey =
    params.order.id?.trim() ||
    (params.order.txHashes[0] ? `tx:${params.order.txHashes[0]}` : "");
  const alreadyOrder =
    typeof existingData.payerSuccessNotifiedOrderId === "string"
      ? existingData.payerSuccessNotifiedOrderId
      : "";
  if (orderKey && alreadyOrder === orderKey) {
    return false;
  }

  const ok = await notifyPayerPaymentSuccess({
    payerPrivateUserId: params.row.receiverPrivateUserId,
    invoiceId: params.row.id,
  });

  if (ok) {
    const table = invoicesTable();
    if (table) {
      existingData.payerSuccessNotified = true;
      if (orderKey) existingData.payerSuccessNotifiedOrderId = orderKey;
      existingData.payerSuccessNotifiedAt = new Date().toISOString();
      const { error } = await table
        .update({ data: existingData })
        .eq("id", params.row.id);
      if (error) {
        console.warn("⚠️ Failed to persist payerSuccessNotified", {
          id: params.row.id,
          message: error.message,
        });
      } else {
        params.row.data = existingData;
      }
    }
  } else {
    console.warn("⚠️ Payer success notify failed", {
      invoiceId: params.row.id,
      receiverPrivateUserId: params.row.receiverPrivateUserId,
      orderKey: orderKey || null,
    });
  }

  return ok;
};

const settlePrivatePaid = async (params: {
  row: PrivateInvoiceRow;
  order: MoneriumOrderSummary;
  txHash: string;
  notifyPayer?: boolean;
}): Promise<SettleResult> => {
  const shouldNotifyPayer = params.notifyPayer !== false;
  const status = normalizeStatus(params.row.status);
  if (status === "PAID") {
    // Already settled (Alchemy, prior reconcile, etc.). Do not push again —
    // Statements reconcile used to re-notify the payer here.
    return {
      matched: true,
      path: "private",
      invoiceId: params.row.id,
      table: "digital_invoices",
      alreadyPaid: true,
      externalPaymentCount: null,
      notified: false,
      detail: "already_paid",
    };
  }

  const table = invoicesTable();
  if (!table) {
    return {
      matched: true,
      path: "private",
      invoiceId: params.row.id,
      table: "digital_invoices",
      alreadyPaid: false,
      externalPaymentCount: null,
      notified: false,
      detail: "supabase_missing",
    };
  }

  const update: Record<string, unknown> = {
    status: "PAID",
    paidOnDate: todayYmd(),
  };
  if (params.txHash) update.txHash = params.txHash;
  if (params.order.id) update.moneriumOrderId = params.order.id;

  const { error } = await table.update(update).eq("id", params.row.id);
  if (error) {
    console.error("❌ Failed to mark digital_invoices PAID", {
      id: params.row.id,
      message: error.message,
    });
    return {
      matched: true,
      path: "private",
      invoiceId: params.row.id,
      table: "digital_invoices",
      alreadyPaid: false,
      externalPaymentCount: null,
      notified: false,
      detail: error.message,
    };
  }

  const publicPaymentCount = await recordPublicPaymentForClaimedInvoice({
    digitalInvoiceId: params.row.id,
    order: params.order,
    payerPrivateUserId: params.row.receiverPrivateUserId,
  });

  const notifiedOwner = await notifyPaid({
    ownerPrivateUserId: params.row.senderPrivateUserId,
    invoiceId: params.row.id,
    payerHint: await resolveClaimerDisplayName(
      params.row.receiverPrivateUserId,
    ),
  });
  const notifiedPayer = shouldNotifyPayer
    ? await notifyPayerOnceForOrder({
        row: params.row,
        order: params.order,
      })
    : false;
  const notified = notifiedOwner || notifiedPayer;

  console.log("💾 digital_invoices settled PAID", {
    id: params.row.id,
    orderId: params.order.id,
    txHash: params.txHash,
    notifiedOwner,
    notifiedPayer,
    receiverPrivateUserId: params.row.receiverPrivateUserId,
    publicPaymentCount,
  });

  return {
    matched: true,
    path: "private",
    invoiceId: params.row.id,
    table: "digital_invoices",
    alreadyPaid: false,
    externalPaymentCount: publicPaymentCount,
    notified,
  };
};

const settlePrivateRejected = async (
  row: PrivateInvoiceRow,
): Promise<SettleResult> => {
  const status = normalizeStatus(row.status);
  if (status === "PAID") {
    return {
      matched: true,
      path: "rejected",
      invoiceId: row.id,
      table: "digital_invoices",
      alreadyPaid: true,
      externalPaymentCount: null,
      notified: false,
      detail: "already_paid_keep",
    };
  }
  if (status !== "PROCESSING") {
    return {
      matched: true,
      path: "rejected",
      invoiceId: row.id,
      table: "digital_invoices",
      alreadyPaid: false,
      externalPaymentCount: null,
      notified: false,
      detail: `status_${status}_unchanged`,
    };
  }

  const table = invoicesTable();
  if (!table) {
    return {
      matched: true,
      path: "rejected",
      invoiceId: row.id,
      table: "digital_invoices",
      alreadyPaid: false,
      externalPaymentCount: null,
      notified: false,
      detail: "supabase_missing",
    };
  }

  await table.update({ status: "UNPAID", paidOnDate: null }).eq("id", row.id);

  return {
    matched: true,
    path: "rejected",
    invoiceId: row.id,
    table: "digital_invoices",
    alreadyPaid: false,
    externalPaymentCount: null,
    notified: false,
    detail: "set_unpaid",
  };
};

const settlePublicPaid = async (params: {
  row: PublicInvoiceRow;
  order: MoneriumOrderSummary;
}): Promise<SettleResult> => {
  const paymentKey =
    params.order.id?.trim() ||
    `public:${params.row.id}:${params.order.txHashes[0] ?? "unknown"}`;

  const recorded = await recordPublicPayment({
    publicId: params.row.id,
    payer: {
      iban: params.order.counterpartIban,
      name: params.order.counterpartName,
      moneriumOrderId: params.order.id,
      source: "external",
      paymentKey,
    },
  });

  if (!recorded.recorded) {
    return {
      matched: true,
      path: "public",
      invoiceId: params.row.id,
      table: "public_digital_invoices",
      alreadyPaid: recorded.detail === "duplicate_payment",
      externalPaymentCount: recorded.count,
      notified: false,
      detail: recorded.detail ?? "not_recorded",
    };
  }

  const notified = await notifyPaid({
    ownerPrivateUserId: params.row.senderPrivateUserId,
    invoiceId: params.row.id,
    payerHint: params.order.counterpartName,
  });

  return {
    matched: true,
    path: "public",
    invoiceId: params.row.id,
    table: "public_digital_invoices",
    alreadyPaid: false,
    externalPaymentCount: recorded.count,
    notified,
  };
};

const findProcessingPrivateForPayer = async (
  privateUserId?: string | null,
): Promise<PrivateInvoiceRow[]> => {
  const table = invoicesTable();
  const prefer = asNumberId(privateUserId);
  if (!table || !prefer) return [];
  const { data, error } = await table
    .select(
      "id, status, amount, referenceNo, senderIban, moneriumOrderId, senderPrivateUserId, receiverPrivateUserId, data",
    )
    .eq("receiverPrivateUserId", prefer)
    .eq("status", "PROCESSING")
    .order("id", { ascending: false })
    .limit(20);
  if (error || !Array.isArray(data)) return [];
  return data as PrivateInvoiceRow[];
};

/** True when settle wrote (or confirmed) private PAID. */
const isPrivatePaidResult = (result: SettleResult): boolean =>
  result.matched &&
  result.path === "private" &&
  result.detail !== "batch_sum_mismatch" &&
  (result.alreadyPaid ||
    result.detail == null ||
    result.detail === "already_paid" ||
    result.detail === "already_paid_payer_notified" ||
    (typeof result.detail === "string" &&
      result.detail.startsWith("batch_paid:")));

const settlePrivateRowsFromOrder = async (params: {
  rows: PrivateInvoiceRow[];
  order: MoneriumOrderSummary;
  txHash: string;
  state: string;
  readyToMarkPaid: boolean;
}): Promise<SettleResult> => {
  const rows = params.rows;
  const first = rows[0];
  if (!first) {
    return {
      matched: false,
      path: "none",
      invoiceId: null,
      table: null,
      alreadyPaid: false,
      externalPaymentCount: null,
      notified: false,
      detail: "no_match",
    };
  }

  if (params.state === "rejected") {
    let last = await settlePrivateRejected(first);
    for (let i = 1; i < rows.length; i++) {
      last = await settlePrivateRejected(rows[i]!);
    }
    return {
      ...last,
      detail:
        rows.length > 1 ? `batch_rejected:${rows.length}` : last.detail,
    };
  }

  if (!params.readyToMarkPaid) {
    return {
      matched: true,
      path: "private",
      invoiceId: first.id,
      table: "digital_invoices",
      alreadyPaid: rows.every((row) => normalizeStatus(row.status) === "PAID"),
      externalPaymentCount: null,
      notified: false,
      detail: `order_state_${params.state}`,
    };
  }

  if (
    rows.length > 1 &&
    !amountsEqual2dp(invoiceAmountSum(rows), params.order.amount)
  ) {
    console.warn("⚠️ Batch settle amount mismatch", {
      orderId: params.order.id,
      orderAmount: params.order.amount,
      invoiceIds: rows.map((row) => row.id),
      invoiceSum: invoiceAmountSum(rows),
    });
    return {
      matched: true,
      path: "private",
      invoiceId: first.id,
      table: "digital_invoices",
      alreadyPaid: false,
      externalPaymentCount: null,
      notified: false,
      detail: "batch_sum_mismatch",
    };
  }

  let last: SettleResult | null = null;
  let notified = false;
  let alreadyPaid = true;
  for (let i = 0; i < rows.length; i++) {
    last = await settlePrivatePaid({
      row: rows[i]!,
      order: params.order,
      txHash: params.txHash,
      notifyPayer: i === 0,
    });
    notified = notified || last.notified;
    if (!last.alreadyPaid) alreadyPaid = false;
  }

  return {
    ...last!,
    notified,
    alreadyPaid,
    detail:
      rows.length > 1
        ? `batch_paid:${rows.length}`
        : last!.detail,
  };
};

/**
 * Match a Monerium order to a private/public invoice and settle when processed.
 */
export const settleInvoiceFromOrder = async (params: {
  order: MoneriumOrderSummary;
  txHash: string;
  privateUserId?: string | null;
}): Promise<SettleResult> => {
  const { order, txHash, privateUserId } = params;
  const state = (order.state ?? "").trim().toLowerCase();

  const none = (detail: string): SettleResult => ({
    matched: false,
    path: "none",
    invoiceId: null,
    table: null,
    alreadyPaid: false,
    externalPaymentCount: null,
    notified: false,
    detail,
  });

  if (!getSupabaseAdmin()) {
    return none("supabase_missing");
  }

  // --- Match ---
  let match:
    | { table: "digital_invoices"; row: PrivateInvoiceRow }
    | { table: "public_digital_invoices"; row: PublicInvoiceRow }
    | null = null;
  let privateBatch: PrivateInvoiceRow[] = [];

  if (order.id) {
    privateBatch = await findPrivatesByOrderId(order.id);
    if (privateBatch.length > 0) {
      match = { table: "digital_invoices", row: privateBatch[0]! };
    }
  }

  if (!match && order.referenceNumber?.trim()) {
    match = await findByReference(order.referenceNumber, privateUserId);
  }

  if (!match) {
    const sbId = parseSbInvoiceIdFromOrder(order);
    if (sbId) {
      const privateRow = await findPrivateById(sbId);
      if (privateRow) {
        match = { table: "digital_invoices", row: privateRow };
        if (order.id) {
          const byOrder = await findPrivatesByOrderId(order.id);
          privateBatch = byOrder.length > 0 ? byOrder : [privateRow];
        } else {
          privateBatch = [privateRow];
        }
        console.log("ℹ️ Matched invoice by in-app sb id", {
          invoiceId: sbId,
          orderId: order.id,
          kind: order.kind,
          memo: order.memo,
          referenceNumber: order.referenceNumber,
        });
      } else {
        const publicRow = await findPublicById(sbId);
        if (publicRow) {
          match = { table: "public_digital_invoices", row: publicRow };
        }
      }
    }
  }

  if (!match) {
    // Amount+IBAN is only for external-bank payments (no in-app order id / sb marker).
    const inPlatform = Boolean(parseSbInvoiceIdFromOrder(order));
    if (!inPlatform && (order.kind ?? "").toLowerCase() === "redeem") {
      match = await findByAmountAndIban(
        order.amount,
        order.counterpartIban,
        privateUserId,
      );
    }
  }

  if (!match) {
    return none("no_match");
  }

  const chainConfirmed = Boolean(txHash && txHash.trim());
  const terminalFail = new Set([
    "cancelled",
    "canceled",
    "failed",
    "expired",
  ]);
  // No Monerium-status polling: treat a non-failed order with a chain txHash
  // as settled (Monerium can stay "pending" for many minutes after mint/burn).
  const readyToMarkPaid =
    !state ||
    state === "processed" ||
    (chainConfirmed && !terminalFail.has(state));

  if (match.table === "digital_invoices") {
    const rows =
      privateBatch.length > 0 ? privateBatch : [match.row];
    return settlePrivateRowsFromOrder({
      rows,
      order,
      txHash,
      state,
      readyToMarkPaid,
    });
  }

  if (state === "rejected") {
    return {
      matched: true,
      path: "rejected",
      invoiceId: match.row.id,
      table: "public_digital_invoices",
      alreadyPaid: normalizeStatus(match.row.status) === "PAID",
      externalPaymentCount: match.row.externalPaymentCount ?? 0,
      notified: false,
      detail: "public_rejected_noop",
    };
  }

  if (!readyToMarkPaid) {
    return {
      matched: true,
      path: "public",
      invoiceId: match.row.id,
      table: match.table,
      alreadyPaid: normalizeStatus(match.row.status) === "PAID",
      externalPaymentCount: match.row.externalPaymentCount ?? 0,
      notified: false,
      detail: `order_state_${state}`,
    };
  }

  return settlePublicPaid({ row: match.row, order });
};

export const settleInvoicesFromOrders = async (params: {
  orders: MoneriumOrderSummary[];
  txHash: string;
  privateUserId?: string | null;
  kind?: "mint" | "burn" | "transfer";
  amountHint?: string | null;
}): Promise<SettleResult[]> => {
  const results: SettleResult[] = [];
  for (const order of params.orders) {
    const result = await settleInvoiceFromOrder({
      order,
      txHash: params.txHash,
      privateUserId: params.privateUserId,
    });
    results.push(result);
  }

  if (results.some(isPrivatePaidResult)) {
    return results;
  }

  // Payer-side burn: match PROCESSING invoices by the stored Monerium order id.
  const open = await findProcessingPrivateForPayer(params.privateUserId);
  if (open.length > 0 && params.orders.length > 0) {
    for (const order of params.orders) {
      if (!order.id) continue;
      const rows = open.filter(
        (invoice) =>
          (invoice.moneriumOrderId ?? "").trim() === order.id!.trim(),
      );
      if (rows.length === 0) continue;
      if (
        results.some(
          (r) =>
            rows.some((row) => r.invoiceId === row.id) &&
            isPrivatePaidResult(r),
        )
      ) {
        continue;
      }
      const settled = await settlePrivateRowsFromOrder({
        rows,
        order,
        txHash: params.txHash,
        state: (order.state ?? "").trim().toLowerCase(),
        readyToMarkPaid: true,
      });
      results.push({
        ...settled,
        detail: settled.detail ?? "fallback_order_id",
      });
    }
  }

  if (results.some(isPrivatePaidResult)) {
    return results;
  }

  // Payee mint from an external bank (friend SEPA / SlickBills user without
  // Monerium). Match amount + description; [sb:id] almost never survives banks.
  const inPlatformMint = params.orders.some((order) =>
    Boolean(parseSbInvoiceIdFromOrder(order)),
  );
  if (params.kind === "mint" && !inPlatformMint) {
    const remittanceHint = params.orders
      .map((o) => o.memo?.trim())
      .filter((m): m is string => Boolean(m && m.length > 0))
      .join(" ");
    const primaryOrder =
      params.orders.find((o) => (o.kind ?? "").toLowerCase() === "issue") ??
      params.orders[0] ??
      null;
    const incoming = await settleIncomingMintForOwner({
      ownerPrivateUserId: params.privateUserId,
      txHash: params.txHash,
      amountHint: params.amountHint ?? primaryOrder?.amount ?? null,
      remittanceHint: remittanceHint || primaryOrder?.memo || null,
      order: primaryOrder,
    });
    if (incoming) {
      results.push(incoming);
    }
  }

  return results;
};

const findOpenSentPrivateForOwner = async (
  ownerPrivateUserId: number,
): Promise<PrivateInvoiceRow[]> => {
  const table = invoicesTable();
  if (!table) return [];
  const { data, error } = await table
    .select(
      "id, status, amount, description, referenceNo, senderIban, moneriumOrderId, senderPrivateUserId, receiverPrivateUserId, data",
    )
    .eq("senderPrivateUserId", ownerPrivateUserId)
    .in("status", Array.from(OPEN_STATUSES))
    .order("id", { ascending: false })
    .limit(50);
  if (error || !Array.isArray(data)) return [];
  return data as PrivateInvoiceRow[];
};

const findOpenPublicSentForOwner = async (
  ownerPrivateUserId: number,
): Promise<PublicInvoiceRow[]> => {
  const table = publicInvoicesTable();
  if (!table) return [];
  const { data, error } = await table
    .select(
      "id, status, amount, description, referenceNo, senderIban, senderPrivateUserId, externalPaymentCount, data, paidOnDate",
    )
    .eq("senderPrivateUserId", ownerPrivateUserId)
    .in("status", Array.from(OPEN_STATUSES))
    .order("id", { ascending: false })
    .limit(50);
  if (error || !Array.isArray(data)) return [];
  return data as PublicInvoiceRow[];
};

const pickInvoiceByAmountAndDescription = <
  T extends { amount: number | null; description?: string | null },
>(
  rows: T[],
  euro: string | null,
  remittance: string | null,
): T | null => {
  const amountHits = euro
    ? rows.filter((row) => amountsEqual2dp(row.amount, euro))
    : [];

  if (amountHits.length === 1) {
    return amountHits[0]!;
  }

  if (amountHits.length > 1 && remittance) {
    const descHits = amountHits.filter((row) =>
      remittanceMatchesDescription(remittance, row.description),
    );
    if (descHits.length === 1) return descHits[0]!;
  }

  // Single open bill overall + amount matches (or no amount hint).
  if (
    rows.length === 1 &&
    (euro == null || amountsEqual2dp(rows[0]!.amount, euro))
  ) {
    return rows[0]!;
  }

  // Amount ambiguous / missing, but description uniquely identifies one bill.
  if (remittance) {
    const descOnly = rows.filter((row) =>
      remittanceMatchesDescription(remittance, row.description),
    );
    if (descOnly.length === 1) {
      if (euro == null || amountsEqual2dp(descOnly[0]!.amount, euro)) {
        return descOnly[0]!;
      }
    }
  }

  return null;
};

const parseEuroAmountHint = (raw?: string | null): string | null => {
  if (!raw) return null;
  const trimmed = raw.trim();
  if (!trimmed) return null;
  if (trimmed.includes(".")) {
    const n = Number(trimmed);
    return Number.isFinite(n) ? n.toFixed(2) : null;
  }
  if (/^\d+$/.test(trimmed) && trimmed.length >= 16) {
    const n = Number(trimmed) / 1e18;
    return Number.isFinite(n) ? n.toFixed(2) : null;
  }
  const n = Number(trimmed);
  return Number.isFinite(n) ? n.toFixed(2) : null;
};

const syntheticIncomingOrder = (params: {
  row: { moneriumOrderId?: string | null; amount: number | null; referenceNo: string | null };
  txHash: string;
  amountHint: string | null;
  remittanceHint?: string | null;
  order?: MoneriumOrderSummary | null;
}): MoneriumOrderSummary => {
  const base = params.order;
  return {
    id: base?.id ?? params.row.moneriumOrderId ?? null,
    kind: base?.kind ?? "issue",
    state: base?.state ?? "processed",
    amount:
      params.amountHint ??
      base?.amount ??
      (params.row.amount != null ? String(params.row.amount) : null),
    currency: base?.currency ?? "eur",
    memo: base?.memo ?? params.remittanceHint ?? null,
    referenceNumber: base?.referenceNumber ?? params.row.referenceNo,
    address: base?.address ?? null,
    counterpartIban: base?.counterpartIban ?? null,
    counterpartName: base?.counterpartName ?? null,
    txHashes:
      base?.txHashes?.length ? base.txHashes : [params.txHash],
    raw: base?.raw ?? { source: "incoming_mint_fallback" },
  };
};

/**
 * Alchemy mint on the payee wallet after an external SEPA credit (public bill,
 * or private bill paid from a bank — including a SlickBills user without
 * Monerium). Match amount + description; do not rely on `[sb:id]`.
 */
export async function settleIncomingMintForOwner(params: {
  ownerPrivateUserId?: string | null;
  txHash: string;
  amountHint?: string | null;
  remittanceHint?: string | null;
  order?: MoneriumOrderSummary | null;
}): Promise<SettleResult | null> {
  const ownerId = asNumberId(params.ownerPrivateUserId);
  if (!ownerId) return null;

  const euro = parseEuroAmountHint(
    params.amountHint ?? params.order?.amount ?? null,
  );
  const remittance =
    params.remittanceHint?.trim() ||
    params.order?.memo?.trim() ||
    null;

  const privateOpen = (await findOpenSentPrivateForOwner(ownerId)).filter(
    (row) => !(row.moneriumOrderId ?? "").trim(),
  );
  const privateRow = pickInvoiceByAmountAndDescription(
    privateOpen,
    euro,
    remittance,
  );

  if (privateRow) {
    console.log("ℹ️ Incoming mint matched sent private invoice", {
      invoiceId: privateRow.id,
      ownerPrivateUserId: ownerId,
      amountHint: euro,
      remittanceHint: remittance,
      txHash: params.txHash,
    });
    const settled = await settlePrivatePaid({
      row: privateRow,
      order: syntheticIncomingOrder({
        row: privateRow,
        txHash: params.txHash,
        amountHint: euro,
        remittanceHint: remittance,
        order: params.order,
      }),
      txHash: params.txHash,
    });
    return { ...settled, detail: settled.detail ?? "incoming_mint_owner" };
  }

  const publicOpen = await findOpenPublicSentForOwner(ownerId);
  const publicRow = pickInvoiceByAmountAndDescription(
    publicOpen,
    euro,
    remittance,
  );

  if (publicRow) {
    console.log("ℹ️ Incoming mint matched sent public invoice", {
      invoiceId: publicRow.id,
      ownerPrivateUserId: ownerId,
      amountHint: euro,
      remittanceHint: remittance,
      description: publicRow.description,
      txHash: params.txHash,
    });
    const settled = await settlePublicPaid({
      row: publicRow,
      order: syntheticIncomingOrder({
        row: publicRow,
        txHash: params.txHash,
        amountHint: euro,
        remittanceHint: remittance,
        order: params.order,
      }),
    });
    return { ...settled, detail: settled.detail ?? "incoming_mint_owner_public" };
  }

  console.log("ℹ️ Incoming mint did not match an open sent invoice", {
    ownerPrivateUserId: ownerId,
    amountHint: euro,
    remittanceHint: remittance,
    privateOpen: privateOpen.length,
    publicOpen: publicOpen.length,
    txHash: params.txHash,
  });
  return null;
};

/** PROCESSING invoices for a payer (receiver) — used when txHash order list is empty. */
export const listProcessingInvoicesForPayer = async (
  privateUserId?: string | null,
): Promise<PrivateInvoiceRow[]> => findProcessingPrivateForPayer(privateUserId);

/** Persist order id + PROCESSING so Alchemy settle can match reliably. */
export const linkInvoicesToMoneriumOrder = async (params: {
  invoiceIds: number[];
  orderId: string;
  payerPrivateUserId?: string | null;
}): Promise<{ ok: boolean; detail?: string; linked: number }> => {
  const uniqueIds = [...new Set(params.invoiceIds.filter((id) => id > 0))];
  if (uniqueIds.length === 0) {
    return { ok: false, detail: "invalid_args", linked: 0 };
  }
  let linked = 0;
  let lastDetail: string | undefined;
  for (const invoiceId of uniqueIds) {
    const result = await linkInvoiceToMoneriumOrder({
      invoiceId,
      orderId: params.orderId,
      payerPrivateUserId: params.payerPrivateUserId,
    });
    if (result.ok) {
      linked += 1;
    } else {
      lastDetail = result.detail;
    }
  }
  return {
    ok: linked > 0,
    detail: linked === uniqueIds.length ? undefined : lastDetail,
    linked,
  };
};

export const linkInvoiceToMoneriumOrder = async (params: {
  invoiceId: number;
  orderId: string;
  payerPrivateUserId?: string | null;
}): Promise<{ ok: boolean; detail?: string }> => {
  const table = invoicesTable();
  if (!table) return { ok: false, detail: "supabase_missing" };
  const invoiceId = asNumberId(params.invoiceId);
  const orderId = params.orderId.trim();
  if (!invoiceId || !orderId) {
    return { ok: false, detail: "invalid_args" };
  }

  const row = await findPrivateById(invoiceId);
  if (!row) return { ok: false, detail: "invoice_not_found" };

  const payer = asNumberId(params.payerPrivateUserId);
  if (
    payer &&
    asNumberId(row.receiverPrivateUserId) != null &&
    asNumberId(row.receiverPrivateUserId) !== payer
  ) {
    return { ok: false, detail: "payer_mismatch" };
  }

  const status = normalizeStatus(row.status);
  const update: Record<string, unknown> = {
    moneriumOrderId: orderId,
  };
  if (status === "UNPAID" || status === "PENDING" || status === "PROCESSING") {
    update.status = "PROCESSING";
  }

  const { error } = await table.update(update).eq("id", invoiceId);
  if (error) {
    console.error("❌ linkInvoiceToMoneriumOrder failed", {
      invoiceId,
      orderId,
      message: error.message,
    });
    return { ok: false, detail: error.message };
  }

  console.log("💾 linked digital_invoices to Monerium order", {
    invoiceId,
    orderId,
    status: update.status ?? status,
  });
  return { ok: true };
};

/** Max inbound orders scanned per statements reconcile (no external API). */
const STATEMENT_RECONCILE_MAX_ORDERS = 25;

/**
 * Catch-up settle from orders the client already loaded on Statements.
 * No Monerium or Alchemy HTTP — Supabase match only (amount+description /
 * sb-id / linked order id). Safe to re-run; public uses settledPaymentKeys.
 */
export async function reconcileInvoicesFromStatementOrders(params: {
  privateUserId: string;
  orders: unknown[];
}): Promise<{
  scanned: number;
  matched: number;
  newlyRecorded: number;
  results: SettleResult[];
}> {
  const ownerId = asNumberId(params.privateUserId);
  if (!ownerId) {
    return { scanned: 0, matched: 0, newlyRecorded: 0, results: [] };
  }

  const seenIds = new Set<string>();
  const summaries: MoneriumOrderSummary[] = [];
  for (const raw of params.orders) {
    if (summaries.length >= STATEMENT_RECONCILE_MAX_ORDERS) break;
    const order = summarizeMoneriumOrder(raw);
    if (!order.id) continue;
    if (seenIds.has(order.id)) continue;
    if ((order.kind ?? "").toLowerCase() !== "issue") continue;
    const state = (order.state ?? "").trim().toLowerCase();
    if (state && state !== "processed") continue;
    seenIds.add(order.id);
    summaries.push(order);
  }

  const results: SettleResult[] = [];
  for (const order of summaries) {
    const txHash =
      order.txHashes.map((h) => h.trim()).find((h) => h.length > 0) ||
      `statement:${order.id}`;

    let result = await settleInvoiceFromOrder({
      order,
      txHash,
      privateUserId: String(ownerId),
    });

    // External SEPA mint: no [sb:id] — match open public/private by amount+desc.
    if (!result.matched && !parseSbInvoiceIdFromOrder(order)) {
      const incoming = await settleIncomingMintForOwner({
        ownerPrivateUserId: String(ownerId),
        txHash,
        amountHint: order.amount,
        remittanceHint: order.memo,
        order,
      });
      if (incoming) result = incoming;
    }

    results.push(result);
  }

  const matched = results.filter((r) => r.matched).length;
  const newlyRecorded = results.filter(
    (r) =>
      r.matched &&
      !r.alreadyPaid &&
      r.detail !== "duplicate_payment" &&
      (r.path === "private" || r.path === "public"),
  ).length;

  console.log("ℹ️ Statements reconcile finished", {
    ownerPrivateUserId: ownerId,
    scanned: summaries.length,
    matched,
    newlyRecorded,
  });

  return {
    scanned: summaries.length,
    matched,
    newlyRecorded,
    results,
  };
}
