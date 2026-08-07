// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

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
    const {
      privateUserId,
      senderName,
      senderIban,
      receiverPrivateUserId,
      receiverUserId,
      receiverIsPrivate,
      amount,
      description,
      dueDate,
      referenceNo,
      category,
    } = await req.json();

    if (
      !confirmedRequiredParams([
        privateUserId,
        senderName,
        receiverPrivateUserId,
        receiverUserId,
        receiverIsPrivate,
        senderIban,
        amount,
        description,
        dueDate,
        category,
      ])
    ) {
      return new Response(JSON.stringify(errorResponseData), {
        headers: { "Content-Type": "application/json" },
      });
    }

    const { data: senderData, error: senderError } = await supabase
      .from("senders")
      .insert({
        privateUserId,
      })
      .select();

    if (senderError) {
      const responseData = {
        isRequestSuccessfull: false,
        data: null,
        error: senderError,
      };

      return new Response(JSON.stringify(responseData), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: receiverData, error: receiverError } = await supabase
      .from("receivers")
      .insert(
        receiverIsPrivate
          ? {
              privateUserId: receiverPrivateUserId,
            }
          : {
              businessUserId: receiverPrivateUserId,
            },
      )
      .select();

    if (receiverError) {
      const responseData = {
        isRequestSuccessfull: false,
        data: null,
        error: receiverError,
      };

      return new Response(JSON.stringify(responseData), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: digitalInvoiceData, error: digitalInvoiceError } =
      await supabase
        .from("digital_invoices")
        .insert({
          senderId: senderData[0].id,
          receiverId: receiverData[0].id,
          amount,
          description,
          senderName,
          senderIban,
          deadline: dueDate,
          invoiceNo: `${privateUserId}${Date.now()}`,
          referenceNo,
          category,
          receiverPrivateUserId: receiverPrivateUserId,
          senderPrivateUserId: privateUserId,
        })
        .select();

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

    const { data: sender, error: _senderError2 } = await supabase
      .from("private_users")
      .select("firstName, lastName")
      .eq("id", privateUserId)
      .single();

    const { data: receiverUser } = await supabase
      .from("users")
      .select("fcm_token")
      .eq("id", receiverUserId)
      .single();

    const fcmToken = receiverUser?.fcm_token as string | null;
    if (fcmToken) {
      await sendFcmPush({
        token: fcmToken,
        title: "New Slickbill!",
        body: sender?.firstName
          ? `${sender?.firstName} sent you a slickbill!`
          : "You received a new slickbill!",
        data: {
          type: "NEW_SLICKBILL",
          invoiceId: digitalInvoiceData[0].id,
        },
      });
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
