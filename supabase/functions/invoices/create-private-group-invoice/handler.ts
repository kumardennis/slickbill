// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

import {
  User,
} from "https://esm.sh/v96/@supabase/gotrue-js@2.16.0/dist/module/index.d.ts";
import {
  confirmedRequiredParams,
  errorResponseData,
} from "../../_shared/confirmedRequiredParams.ts";
import { corsHeaders } from "../../_shared/cors.ts";
import { createSupabase } from "../../_shared/supabaseClient.ts";

type ReceiverUser = {
  receiverUserId: number;
  amount: number;
};

export const handler = async (req: Request) => {
  const supabase = createSupabase(req);

  try {
    const {
      privateUserId,
      senderName,
      receiverUsers,

      description,
      dueDate,
      referenceNo,
      category,
    } = await req
      .json();

    if (
      !confirmedRequiredParams([
        privateUserId,
        senderName,
        receiverUsers,

        description,
        dueDate,
        category,
      ])
    ) {
      return new Response(JSON.stringify(errorResponseData), {
        headers: { "Content-Type": "application/json" },
      });
    }
    const { data: groupData, error: groupError } = await supabase.from(
      "private_groups",
    ).insert({
      creatorUserId: privateUserId,
      deadline: dueDate,
      description,
    }).select();

    if (groupError) {
      const responseData = {
        isRequestSuccessfull: false,
        data: null,
        error: groupError,
      };

      return new Response(JSON.stringify(responseData), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (groupData != null) {
      for (const receiverUser of receiverUsers) {
        const { data: senderData, error: senderError } = await supabase.from(
          "senders",
        ).insert({
          privateUserId,
        }).select();

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
          .from(
            "receivers",
          ).insert({
            privateUserId: receiverUser.receiverUserId,
          }).select();

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
          await supabase.from(
            "digital_invoices",
          ).insert({
            senderId: senderData[0].id,
            receiverId: receiverData[0].id,
            amount: receiverUser.amount,
            description,
            senderName,
            deadline: dueDate,
            invoiceNo: `${privateUserId}${Date.now()}`,
            referenceNo,
            category,
            privateGroupId: groupData[0].id,
          }).select();

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
      }
    }

    const responseData = {
      isRequestSuccessfull: true,
      data: "created",
      error: null,
    };

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
