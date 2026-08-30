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

    const { data: currentInvoice, error: currentInvoiceError } = await supabase
      .from("digital_invoices")
      .select(
        "*, sender:senders (*, private_users (firstName, userId)), receiver:receivers (*, private_users (firstName, userId))",
      )
      .eq("id", invoiceId)
      .single();

    if (currentInvoiceError || !currentInvoice) {
      const responseData = {
        isRequestSuccessfull: false,
        data: null,
        error: currentInvoiceError ?? "Invoice not found",
      };

      return new Response(JSON.stringify(responseData), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const currentStatus = String(currentInvoice.status ?? "")
      .trim()
      .toUpperCase();

    // Settlement can mark PAID before the payer app writes PROCESSING.
    // Never overwrite a paid invoice with processing.
    if (currentStatus === "PAID" && resolvedStatus === "PROCESSING") {
      const responseData = {
        isRequestSuccessfull: true,
        data: currentInvoice,
        error: null,
      };

      return new Response(JSON.stringify(responseData), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const payload: Record<string, unknown> = {
      status: resolvedStatus,
    };
    if (resolvedStatus === "PAID") {
      payload.paidOnDate = dayjs().format("YYYY-MM-DD");
    } else if (resolvedStatus === "UNPAID") {
      payload.paidOnDate = null;
    }

    const { data: digitalInvoiceData, error: digitalInvoiceError } =
      await supabase
        .from("digital_invoices")
        .update(payload)
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

    const notifyUser = async (params: {
      userId: unknown;
      type: string;
      title: string;
      body: string;
    }) => {
      if (params.userId == null || params.userId === "") {
        return;
      }
      const authKey =
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ||
        Deno.env.get("SUPABASE_ANON_KEY") ||
        "";
      const notificationUrl = new URL(Deno.env.get("SUPABASE_URL") || "");
      notificationUrl.pathname =
        "/functions/v1/notifications/send-notification";

      await fetch(notificationUrl.toString(), {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${authKey}`,
          apikey: authKey,
        },
        body: JSON.stringify({
          userId: params.userId,
          type: params.type,
          invoiceId: digitalInvoiceData.id,
          title: params.title,
          body: params.body,
        }),
      });
    };

    if (resolvedStatus === "PAID" || resolvedStatus === "PROCESSING") {
      try {
        const receiverName =
          digitalInvoiceData.receiver?.private_users?.firstName ?? "Someone";

        if (resolvedStatus === "PAID") {
          if (senderUserId) {
            await notifyUser({
              userId: senderUserId,
              type: "SLICKBILL_PAID",
              title: "Slickbill Paid",
              body: `${receiverName} paid your slickbill`,
            });
          } else {
            console.warn("Skipping owner paid notification: missing sender", {
              invoiceId: digitalInvoiceData.id,
            });
          }

          if (receiverUserId && receiverUserId !== senderUserId) {
            await notifyUser({
              userId: receiverUserId,
              type: "SLICKBILL_PAYMENT_SUCCESS",
              title: "Payment successful",
              body: "Your slickbill payment went through.",
            });
          }
        } else if (receiverUserId) {
          await notifyUser({
            userId: receiverUserId,
            type: "SLICKBILL_PROCESSING",
            title: "Payment in process",
            body: "Your invoice payment has been initiated and is now processing.",
          });
        } else {
          console.warn("Skipping processing notification: missing receiver", {
            invoiceId: digitalInvoiceData.id,
          });
        }
      } catch (notificationError) {
        console.error("Failed to send notification:", notificationError);
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
