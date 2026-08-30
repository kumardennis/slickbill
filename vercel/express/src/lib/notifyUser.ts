import { getSupabaseAdmin } from "./supabaseAdmin.js";

type SendFcmArgs = {
  userId: string | number;
  type: string;
  title: string;
  body: string;
  data?: Record<string, string | number | null | undefined>;
};

const lookupFcmToken = async (
  userId: string | number,
): Promise<string | null> => {
  const supabase = getSupabaseAdmin();
  if (!supabase) return null;

  const numericId = Number(userId);
  const idFilter = Number.isFinite(numericId) ? numericId : userId;
  const { data } = await (supabase.from("users") as any)
    .select("id, fcm_token")
    .eq("id", idFilter)
    .maybeSingle();

  if (data?.id != null) {
    const direct =
      typeof data.fcm_token === "string" ? data.fcm_token.trim() : "";
    return direct || null;
  }

  if (!Number.isFinite(numericId) || numericId <= 0) return null;

  const { data: privateUser } = await (supabase.from("private_users") as any)
    .select("userId")
    .eq("id", numericId)
    .maybeSingle();
  const mappedUserId = Number(privateUser?.userId);
  if (!Number.isFinite(mappedUserId) || mappedUserId <= 0) return null;

  const { data: mapped } = await (supabase.from("users") as any)
    .select("fcm_token")
    .eq("id", mappedUserId)
    .maybeSingle();
  const mappedToken =
    typeof mapped?.fcm_token === "string" ? mapped.fcm_token.trim() : "";
  return mappedToken || null;
};

const isSendSuccess = (payload: unknown): boolean => {
  if (!payload || typeof payload !== "object") return false;
  const row = payload as Record<string, unknown>;
  return row.isRequestSuccessfull === true || row.isRequestSuccessful === true;
};

/**
 * Send push via existing Supabase notifications edge function (service role).
 */
export const notifyUserViaSupabase = async (
  args: SendFcmArgs,
): Promise<{ ok: boolean; detail?: string }> => {
  const supabaseUrl = process.env.SUPABASE_URL?.trim();
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
  if (!supabaseUrl || !serviceKey) {
    return { ok: false, detail: "supabase_not_configured" };
  }

  const invoiceId =
    args.data?.invoiceId != null && String(args.data.invoiceId).length > 0
      ? String(args.data.invoiceId)
      : "0";

  const token = await lookupFcmToken(args.userId);
  if (!token) {
    return { ok: false, detail: "missing_fcm_token" };
  }

  try {
    const response = await fetch(
      `${supabaseUrl.replace(/\/$/, "")}/functions/v1/notifications/send-notification`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${serviceKey}`,
          apikey: serviceKey,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          userId: args.userId,
          type: args.type,
          invoiceId,
          title: args.title,
          body: args.body,
          token,
        }),
      },
    );

    const text = await response.text();
    let parsed: unknown = null;
    try {
      parsed = JSON.parse(text);
    } catch {
      parsed = null;
    }

    if (!response.ok || !isSendSuccess(parsed)) {
      return {
        ok: false,
        detail: `http_${response.status}:${text.slice(0, 200)}`,
      };
    }
    return { ok: true, detail: text.slice(0, 200) };
  } catch (error) {
    return {
      ok: false,
      detail: error instanceof Error ? error.message : String(error),
    };
  }
};
