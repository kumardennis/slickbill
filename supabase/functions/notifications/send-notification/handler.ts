// Edge function to send a notification directly (useful for testing)
// POST /functions/v1/notifications/send-notification
// Body: { userId, type, invoiceId, title?, body? }

import {
  confirmedRequiredParams,
  errorResponseData,
} from "../../_shared/confirmedRequiredParams.ts";
import { corsHeaders } from "../../_shared/cors.ts";
import { createSupabase } from "../../_shared/supabaseClient.ts";
import { sendFcmPush } from "../../_shared/fcm.ts";

export const handler = async (req: Request) => {
  const supabase = createSupabase(req);

  try {
    const { userId, type, invoiceId, title, body } = await req.json();

    if (!confirmedRequiredParams([userId, type, invoiceId])) {
      return new Response(JSON.stringify(errorResponseData), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Fetch user's FCM token
    const { data: userData, error: userError } = await supabase
      .from("users")
      .select("fcm_token")
      .eq("id", userId)
      .single();

    if (userError || !userData?.fcm_token) {
      const responseData = {
        isRequestSuccessfull: false,
        data: null,
        error: userError ?? "User not found or no FCM token",
      };
      return new Response(JSON.stringify(responseData), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
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

    // Send FCM notification
    await sendFcmPush({
      token: userData.fcm_token,
      title: finalTitle,
      body: finalBody,
      data: { type, invoiceId },
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
