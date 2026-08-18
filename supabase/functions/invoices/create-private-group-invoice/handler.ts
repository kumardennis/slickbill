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
      senderIsBusiness: senderIsBusinessFromBody,
      receiverUsers,

      description,
      dueDate,
      referenceNo,
      category,
    } = await req.json();

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
    const { data: groupData, error: groupError } = await supabase
      .from("private_groups")
      .insert({
        creatorUserId: privateUserId,
        deadline: dueDate,
        description,
      })
      .select();

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
      const { data: senderProfile } = await supabase
        .from("private_users")
        .select("isBusiness")
        .eq("id", privateUserId)
        .maybeSingle();

      const senderIsBusiness = typeof senderIsBusinessFromBody === "boolean"
        ? senderIsBusinessFromBody
        : senderProfile?.isBusiness === true;

      for (const receiverUser of receiverUsers) {
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
          .insert({
            privateUserId: receiverUser.receiverPrivateUserId,
          })
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
              amount: receiverUser.amount,
              description,
              senderName,
              senderIsBusiness,
              deadline: dueDate,
              invoiceNo: `${privateUserId}${Date.now()}`,
              referenceNo,
              category,
              receiverPrivateUserId: receiverUser.receiverPrivateUserId,
              privateGroupId: groupData[0].id,
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

        const { data: receiverAppUser } = await supabase
          .from("users")
          .select("fcm_token")
          .eq("id", receiverUser.receiverUserId)
          .single();

        const fcmToken = receiverAppUser?.fcm_token as string | null;
        if (fcmToken) {
          await sendFcmPush({
            token: fcmToken,
            title: "New Slickbill!",
            body: senderName
              ? `${senderName} sent you a slickbill!`
              : "You received a new slickbill!",
            data: {
              type: "NEW_SLICKBILL",
              invoiceId: digitalInvoiceData[0].id,
            },
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
