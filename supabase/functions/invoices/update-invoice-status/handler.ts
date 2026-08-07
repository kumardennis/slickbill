// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

import {
  confirmedRequiredParams,
  errorResponseData,
} from "../../_shared/confirmedRequiredParams.ts";
import { corsHeaders } from "../../_shared/cors.ts";
import { createSupabase } from "../../_shared/supabaseClient.ts";
import dayjs from "https://deno.land/x/deno_dayjs@v0.5.0/mod.ts";

export const handler = async (req: Request) => {
  const supabase = createSupabase(req);

  try {
    const { invoiceId, isPaid, status } = await req.json();

    const hasIsPaid = typeof isPaid === "boolean";
    const hasStatus = typeof status === "string" && status.trim().length > 0;

    if (!confirmedRequiredParams([invoiceId]) || (!hasIsPaid && !hasStatus)) {
      return new Response(JSON.stringify(errorResponseData), {
        headers: { "Content-Type": "application/json" },
      });
    }

    const requestedStatus = hasStatus ? status.trim().toUpperCase() : null;
    const resolvedStatus = requestedStatus ?? (isPaid ? "PAID" : "UNPAID");
    const paidOnDate =
      resolvedStatus === "PAID" ? dayjs().format("YYYY-MM-DD") : null;

    const { data: digitalInvoiceData, error: digitalInvoiceError } =
      await supabase
        .from("digital_invoices")
        .update({
          status: resolvedStatus,
          paidOnDate,
        })
        .match({ id: invoiceId })
        .select(
          "*, sender:senders (*, private_users (firstName, userId)), receiver:receivers (*, private_users (firstName, userId))",
        )
        .single();

    if (digitalInvoiceError) {
      const responseData = {
        isRequestSuccessfull: false,
        data: null,
        error: digitalInvoiceError,
      };

      return new Response(JSON.stringify(responseData), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const responseData = {
      isRequestSuccessfull: true,
      data: digitalInvoiceData,
      error: digitalInvoiceError,
    };

    const senderUserId = digitalInvoiceData.sender?.private_users?.userId;
    const receiverUserId = digitalInvoiceData.receiver?.private_users?.userId;

    // Call the send-notification endpoint to send FCM notification
    if (resolvedStatus === "PAID" || resolvedStatus === "PROCESSING") {
      try {
        const notificationUserId =
          resolvedStatus === "PAID" ? senderUserId : receiverUserId;
        const notificationType =
          resolvedStatus === "PAID" ? "SLICKBILL_PAID" : "SLICKBILL_PROCESSING";
        const notificationTitle =
          resolvedStatus === "PAID" ? "Slickbill Paid" : "Payment in process";
        const receiverName =
          digitalInvoiceData.receiver?.private_users?.firstName ?? "Someone";
        const notificationBody =
          resolvedStatus === "PAID"
            ? `${receiverName} paid your slickbill`
            : "Your invoice payment has been initiated and is now processing.";

        if (!notificationUserId) {
          console.warn("Skipping notification due to missing target user", {
            invoiceId: digitalInvoiceData.id,
            status: resolvedStatus,
          });
        } else {
          const notificationUrl = new URL(Deno.env.get("SUPABASE_URL") || "");
          notificationUrl.pathname =
            "/functions/v1/notifications/send-notification";

          await fetch(notificationUrl.toString(), {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${Deno.env.get("SUPABASE_ANON_KEY") || ""}`,
            },
            body: JSON.stringify({
              userId: notificationUserId,
              type: notificationType,
              invoiceId: digitalInvoiceData.id,
              title: notificationTitle,
              body: notificationBody,
            }),
          });
        }
      } catch (notificationError) {
        console.error("Failed to send notification:", notificationError);
        // Don't fail the request if notification fails
      }
    }

    return new Response(JSON.stringify(responseData), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    const responseData = {
      isRequestSuccessfull: false,
      data: null,
      error: err,
    };

    return new Response(JSON.stringify(responseData), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
};
// To invoke:
// curl -i --location --request POST 'http://localhost:54321/functions/v1/' \
//   --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
//   --header 'Content-Type: application/json' \
//   --data '{"name":"Functions"}'
