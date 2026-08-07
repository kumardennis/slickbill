type SendFcmArgs = {
  userId: string | number;
  type: string;
  title: string;
  body: string;
  data?: Record<string, string | number | null | undefined>;
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
        }),
      },
    );

    const text = await response.text();
    if (!response.ok) {
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
