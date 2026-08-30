// Edge function to send a notification directly (useful for testing)
// POST /functions/v1/notifications/send-notification
// Body: { userId, type, invoiceId, title?, body? }

import {
  confirmedRequiredParams,
  errorResponseData,
} from "../../_shared/confirmedRequiredParams.ts";
import { corsHeaders } from "../../_shared/cors.ts";
import {
  createSupabase,
  createSupabaseService,
  isServiceRoleRequest,
} from "../../_shared/supabaseClient.ts";
import { sendFcmPush } from "../../_shared/fcm.ts";

export const handler = async (req: Request) => {
  const supabase = isServiceRoleRequest(req)
    ? createSupabaseService()
    : createSupabase(req);

  try {
    const { userId, type, invoiceId, title, body, token } = await req.json();

    if (!confirmedRequiredParams([userId, type, invoiceId])) {
      return new Response(JSON.stringify(errorResponseData), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const providedToken =
      typeof token === "string" && token.trim().length > 0
        ? token.trim()
        : "";

    let fcmToken = providedToken;
    if (!fcmToken) {
      const appUserId = Number(userId);
      const idFilter = Number.isFinite(appUserId) ? appUserId : userId;
      const { data: userData, error: userError } = await supabase
        .from("users")
        .select("id, fcm_token")
        .eq("id", idFilter)
        .maybeSingle();

      if (userData) {
        fcmToken = (userData.fcm_token as string | null)?.trim() ?? "";
      } else if (Number.isFinite(appUserId) && appUserId > 0) {
        const { data: privateUser } = await supabase
          .from("private_users")
          .select("userId")
          .eq("id", appUserId)
          .maybeSingle();
        const mappedUserId = Number(privateUser?.userId);
        if (Number.isFinite(mappedUserId) && mappedUserId > 0) {
          const { data: mappedUser } = await supabase
            .from("users")
            .select("fcm_token")
            .eq("id", mappedUserId)
            .maybeSingle();
          fcmToken = (mappedUser?.fcm_token as string | null)?.trim() ?? "";
        }
      }

      if (!fcmToken) {
        const responseData = {
          isRequestSuccessfull: false,
          data: null,
          error: userError ?? "User not found or no FCM token",
        };
        return new Response(JSON.stringify(responseData), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    // Determine title and body based on type
    let finalTitle = title;
    let finalBody = body;

    if (!finalTitle || !finalBody) {
      switch (type) {
        case "NEW_SLICKBILL":
        case "invoice_received":
          finalTitle = finalTitle ?? "New Slickbill";
          finalBody = finalBody ?? "A new slickbill has arrived.";
          break;
        case "SLICKBILL_PAID":
          finalTitle = finalTitle ?? "Slickbill Paid";
          finalBody = finalBody ?? "One of your slickbills has been paid.";
          break;
        case "SLICKBILL_PAYMENT_SUCCESS":
          finalTitle = finalTitle ?? "Payment successful";
          finalBody = finalBody ?? "Your slickbill payment went through.";
          break;
        case "SLICKBILL_PROCESSING":
        case "monerium_payment_processing":
          finalTitle = finalTitle ?? "Payment in process";
          finalBody =
            finalBody ??
            "Your invoice payment has been initiated and is now processing.";
          break;
        case "SLICKBILL_CLAIMED":
          finalTitle = finalTitle ?? "Slickbill Claimed";
          finalBody = finalBody ?? "Your public slickbill has been claimed.";
          break;
        case "MONERIUM_ACCOUNT_TRANSFER":
          finalTitle = finalTitle ?? "You got money in Slickbills";
          finalBody = finalBody ?? "You got money in Slickbills.";
          break;
        case "payment_reminder":
          finalTitle = finalTitle ?? "Payment reminder";
          finalBody = finalBody ?? "You have an unpaid slickbill waiting.";
          break;
        default:
          finalTitle = finalTitle ?? "Notification";
          finalBody = finalBody ?? "You have a new notification.";
      }
    }

    await sendFcmPush({
      token: fcmToken,
      title: finalTitle,
      body: finalBody,
      data: { type, invoiceId: String(invoiceId) },
    });

    const responseData = {
      isRequestSuccessfull: true,
      data: { sent: true, userId, type, invoiceId },
      error: null,
    };

    return new Response(JSON.stringify(responseData), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    const responseData = {
      isRequestSuccessfull: false,
      data: null,
      error: err instanceof Error ? err.message : String(err),
    };

    return new Response(JSON.stringify(responseData), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
};
