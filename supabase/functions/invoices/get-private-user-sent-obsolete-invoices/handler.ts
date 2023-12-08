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

export const handler = async (req: Request) => {
  const supabase = createSupabase(req);

  try {
    const {
      privateUserId,
      status,
      paidOnDateRange,
    } = await req
      .json();

    if (
      !confirmedRequiredParams([
        privateUserId,
      ])
    ) {
      return new Response(JSON.stringify(errorResponseData), {
        headers: { "Content-Type": "application/json" },
      });
    }

    const query = supabase.from(
      "digital_invoices",
    ).select(
      "*, senders!inner(* , private_users(*)), receivers(* , private_users(*), business_users(*))",
    ).eq(
      "senders.privateUserId",
      privateUserId,
    ).eq("isObsolete", true).order("created_at", { ascending: false }).eq(
      "privateGroupId",
      null,
    );

    if (status) {
      query.eq("status", status);
    }

    if (paidOnDateRange) {
      query.gte("paidOnDate", paidOnDateRange[0]).lte(
        "paidOnDate",
        paidOnDateRange[1],
      );
    }

    const { data: digitalInvoiceData, error: digitalInvoiceError } =
      await query;

    if (digitalInvoiceError) {
      const responseData = {
        isRequestSuccessfull: false,
        data: null,
        error: digitalInvoiceError,
      };

      return new Response(JSON.stringify(responseData), {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json; charset=utf-8",
        },
      });
    }

    const responseData = {
      isRequestSuccessfull: true,
      data: digitalInvoiceData,
      error: digitalInvoiceError,
    };

    return new Response(JSON.stringify(responseData), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json; charset=utf-8",
      },
    });
  } catch (err) {
    const responseData = {
      isRequestSuccessfull: false,
      data: null,
      error: err,
    };

    return new Response(JSON.stringify(responseData), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json; charset=utf-8",
      },
    });
  }
};

// To invoke:
// curl -i --location --request POST 'http://localhost:54321/functions/v1/' \
//   --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
//   --header 'Content-Type: application/json' \
//   --data '{"name":"Functions"}'
