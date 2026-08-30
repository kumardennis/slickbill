import { getSupabaseAdmin } from "./supabaseAdmin.js";
import { notifyUserViaSupabase } from "./notifyUser.js";
import {
  amountsEqual2dp,
  normalizeIban,
  parseSbInvoiceIdFromOrder,
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
  referenceNo: string | null;
  senderIban: string | null;
  senderPrivateUserId: number | string | null;
  externalPaymentCount: number | null;
  data: unknown;
  paidOnDate: string | null;
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

const findPrivateByOrderId = async (
  orderId: string,
): Promise<PrivateInvoiceRow | null> => {
  const table = invoicesTable();
  if (!table || !orderId.trim()) return null;
  const { data, error } = await table
    .select(
      "id, status, amount, referenceNo, senderIban, moneriumOrderId, senderPrivateUserId, receiverPrivateUserId, data",
    )
    .eq("moneriumOrderId", orderId.trim())
    .maybeSingle();
  if (error || !data) return null;
  return data as PrivateInvoiceRow;
};

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

/** Notify payer once per Monerium order (webhook-only). Safe on already-PAID. */
const notifyPayerOnceForOrder = async (params: {
  row: PrivateInvoiceRow;
  order: MoneriumOrderSummary;
}): Promise<boolean> => {
  const orderKey =
    params.order.id?.trim() ||
    (params.order.txHashes[0] ? `tx:${params.order.txHashes[0]}` : "");
  if (!orderKey) {
    // Still try once without dedupe key if we have a payer.
    return notifyPayerPaymentSuccess({
      payerPrivateUserId: params.row.receiverPrivateUserId,
      invoiceId: params.row.id,
    });
  }

  const existingData =
    params.row.data && typeof params.row.data === "object"
      ? { ...(params.row.data as Record<string, unknown>) }
      : {};
  const already =
    typeof existingData.payerSuccessNotifiedOrderId === "string"
      ? existingData.payerSuccessNotifiedOrderId
      : "";
  if (already === orderKey) {
    return false;
  }

  const ok = await notifyPayerPaymentSuccess({
    payerPrivateUserId: params.row.receiverPrivateUserId,
    invoiceId: params.row.id,
  });

  if (ok) {
    const table = invoicesTable();
    if (table) {
      existingData.payerSuccessNotifiedOrderId = orderKey;
      existingData.payerSuccessNotifiedAt = new Date().toISOString();
      const { error } = await table
        .update({ data: existingData })
        .eq("id", params.row.id);
      if (error) {
        console.warn("⚠️ Failed to persist payerSuccessNotifiedOrderId", {
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
      orderKey,
    });
  }

  return ok;
};

const settlePrivatePaid = async (params: {
  row: PrivateInvoiceRow;
  order: MoneriumOrderSummary;
  txHash: string;
}): Promise<SettleResult> => {
  const status = normalizeStatus(params.row.status);
  if (status === "PAID") {
    // Flutter may have marked PAID first (owner notified via edge). Still notify
    // the payer from webhook — once per order.
    const notifiedPayer = await notifyPayerOnceForOrder({
      row: params.row,
      order: params.order,
    });
    return {
      matched: true,
      path: "private",
      invoiceId: params.row.id,
      table: "digital_invoices",
      alreadyPaid: true,
      externalPaymentCount: null,
      notified: notifiedPayer,
      detail: notifiedPayer ? "already_paid_payer_notified" : "already_paid",
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
  const notifiedPayer = await notifyPayerOnceForOrder({
    row: params.row,
    order: params.order,
  });
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
  (result.alreadyPaid ||
    result.detail == null ||
    result.detail === "already_paid" ||
    result.detail === "already_paid_payer_notified");

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

  if (order.id) {
    const byOrder = await findPrivateByOrderId(order.id);
    if (byOrder) {
      match = { table: "digital_invoices", row: byOrder };
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

  if (state === "rejected") {
    if (match.table === "digital_invoices") {
      return settlePrivateRejected(match.row);
    }
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

  // Alchemy (and settle-by-txhash) only run once a chain tx exists. Monerium may
  // still report pending/placed at that moment — do not leave the invoice stuck.
  const chainConfirmed = Boolean(txHash && txHash.trim());
  const terminalFail = new Set([
    "cancelled",
    "canceled",
    "failed",
    "expired",
  ]);
  const readyToMarkPaid =
    !state ||
    state === "processed" ||
    (chainConfirmed && !terminalFail.has(state));

  if (!readyToMarkPaid) {
    return {
      matched: true,
      path: match.table === "digital_invoices" ? "private" : "public",
      invoiceId: match.row.id,
      table: match.table,
      alreadyPaid: normalizeStatus(match.row.status) === "PAID",
      externalPaymentCount:
        match.table === "public_digital_invoices"
          ? (match.row.externalPaymentCount ?? 0)
          : null,
      notified: false,
      detail: `order_state_${state}`,
    };
  }

  if (match.table === "digital_invoices") {
    return settlePrivatePaid({ row: match.row, order, txHash });
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
      const row = open.find(
        (invoice) =>
          (invoice.moneriumOrderId ?? "").trim() === order.id!.trim(),
      );
      if (!row) continue;
      if (results.some((r) => r.invoiceId === row.id && isPrivatePaidResult(r))) {
        continue;
      }
      const settled = await settlePrivatePaid({
        row,
        order,
        txHash: params.txHash,
      });
      results.push({ ...settled, detail: settled.detail ?? "fallback_order_id" });
    }
  }

  if (results.some(isPrivatePaidResult)) {
    return results;
  }

  // Payee mint from an external bank: unique amount, and only invoices that
  // were not paid in-app (no moneriumOrderId). Skip if this mint already
  // carries an in-app invoice marker — do not guess by amount.
  const inPlatformMint = params.orders.some((order) =>
    Boolean(parseSbInvoiceIdFromOrder(order)),
  );
  if (params.kind === "mint" && !inPlatformMint) {
    const incoming = await settleIncomingMintForOwner({
      ownerPrivateUserId: params.privateUserId,
      txHash: params.txHash,
      amountHint: params.amountHint,
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
      "id, status, amount, referenceNo, senderIban, moneriumOrderId, senderPrivateUserId, receiverPrivateUserId, data",
    )
    .eq("senderPrivateUserId", ownerPrivateUserId)
    .in("status", Array.from(OPEN_STATUSES))
    .order("id", { ascending: false })
    .limit(20);
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
      "id, status, amount, referenceNo, senderIban, senderPrivateUserId, externalPaymentCount, data, paidOnDate",
    )
    .eq("senderPrivateUserId", ownerPrivateUserId)
    .in("status", Array.from(OPEN_STATUSES))
    .order("id", { ascending: false })
    .limit(20);
  if (error || !Array.isArray(data)) return [];
  return data as PublicInvoiceRow[];
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
}): MoneriumOrderSummary => ({
  id: params.row.moneriumOrderId ?? null,
  kind: "issue",
  state: "processed",
  amount:
    params.amountHint ??
    (params.row.amount != null ? String(params.row.amount) : null),
  currency: "eur",
  memo: null,
  referenceNumber: params.row.referenceNo,
  address: null,
  counterpartIban: null,
  counterpartName: null,
  txHashes: [params.txHash],
  raw: { source: "incoming_mint_fallback" },
});

/**
 * Alchemy mint hits the payee wallet. In-app pays are matched by invoice id /
 * number on the Monerium order. This path is external-bank only: unique amount
 * on sent invoices that have no in-app Monerium order id.
 */
export async function settleIncomingMintForOwner(params: {
  ownerPrivateUserId?: string | null;
  txHash: string;
  amountHint?: string | null;
}): Promise<SettleResult | null> {
  const ownerId = asNumberId(params.ownerPrivateUserId);
  if (!ownerId) return null;

  const euro = parseEuroAmountHint(params.amountHint);
  const privateOpen = (await findOpenSentPrivateForOwner(ownerId)).filter(
    (row) => !(row.moneriumOrderId ?? "").trim(),
  );
  const privateHits = euro
    ? privateOpen.filter((row) => amountsEqual2dp(row.amount, euro))
    : [];

  let privateRow: PrivateInvoiceRow | null = null;
  if (privateHits.length === 1) {
    privateRow = privateHits[0]!;
  } else if (
    privateOpen.length === 1 &&
    (euro == null || amountsEqual2dp(privateOpen[0]!.amount, euro))
  ) {
    privateRow = privateOpen[0]!;
  }

  if (privateRow) {
    console.log("ℹ️ Incoming mint matched sent private invoice", {
      invoiceId: privateRow.id,
      ownerPrivateUserId: ownerId,
      amountHint: euro,
      txHash: params.txHash,
    });
    const settled = await settlePrivatePaid({
      row: privateRow,
      order: syntheticIncomingOrder({
        row: privateRow,
        txHash: params.txHash,
        amountHint: euro,
      }),
      txHash: params.txHash,
    });
    return { ...settled, detail: settled.detail ?? "incoming_mint_owner" };
  }

  const publicOpen = await findOpenPublicSentForOwner(ownerId);
  const publicHits = euro
    ? publicOpen.filter((row) => amountsEqual2dp(row.amount, euro))
    : [];

  let publicRow: PublicInvoiceRow | null = null;
  if (publicHits.length === 1) {
    publicRow = publicHits[0]!;
  } else if (
    publicOpen.length === 1 &&
    (euro == null || amountsEqual2dp(publicOpen[0]!.amount, euro))
  ) {
    publicRow = publicOpen[0]!;
  }

  if (publicRow) {
    console.log("ℹ️ Incoming mint matched sent public invoice", {
      invoiceId: publicRow.id,
      ownerPrivateUserId: ownerId,
      amountHint: euro,
      txHash: params.txHash,
    });
    const settled = await settlePublicPaid({
      row: publicRow,
      order: syntheticIncomingOrder({
        row: publicRow,
        txHash: params.txHash,
        amountHint: euro,
      }),
    });
    return { ...settled, detail: settled.detail ?? "incoming_mint_owner_public" };
  }

  console.log("ℹ️ Incoming mint did not match an open sent invoice", {
    ownerPrivateUserId: ownerId,
    amountHint: euro,
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
