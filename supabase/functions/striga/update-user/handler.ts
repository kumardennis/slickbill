// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

import { User } from "https://esm.sh/v96/@supabase/gotrue-js@2.16.0/dist/module/index.d.ts";
import {
  confirmedRequiredParams,
  errorResponseData,
} from "../../_shared/confirmedRequiredParams.ts";
import { corsHeaders } from "../../_shared/cors.ts";
import { createSupabase } from "../../_shared/supabaseClient.ts";
import { count } from "node:console";
import {
  calcStrigaAuthSign,
  SANDBOX_API_KEY,
} from "../../_shared/strigaHMAC.ts";

export const handler = async (req: Request) => {
  const supabase = createSupabase(req);

  try {
    const { userId, year, month, day, address } = await req.json();

    if (!confirmedRequiredParams([userId])) {
      return new Response(JSON.stringify(errorResponseData), {
        headers: { "Content-Type": "application/json" },
      });
    }

    const { data: userData, error: userError } = await supabase
      .from("users")
      .select("*, private_users(*)")
      .eq("id", userId);

    if (userError) {
      const responseData = {
        isRequestSuccessfull: false,
        data: null,
        error: userError,
      };

      return new Response(JSON.stringify(responseData), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = {
      userId: userData?.[0]?.strigaUserId,
      dateOfBirth: { year: year, month: month, day: day },
      address: {
        addressLine1: address?.addressLine1,
        addressLine2: address?.addressLine2,
        city: address?.city,
        postalCode: address?.postalCode,
        state: address?.state,
        country: address?.country,
      },
    };

    const strigaFetchOption = {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Authorization: calcStrigaAuthSign(body, "/user/update", "PATCH"),
        "api-key": SANDBOX_API_KEY,
      },
      body: JSON.stringify(body),
    };

    const strigaResponse = await fetch(
      "https://www.sandbox.striga.com/api/v1/user/update",
      strigaFetchOption
    );

    const strigaResponseBody = await strigaResponse.json();

    console.log("strigaResponseBody:", strigaResponseBody);

    if (!strigaResponse.ok) {
      const responseData = {
        isRequestSuccessfull: false,
        data: { strigaFetchOption, userData },
        error: strigaResponseBody,
      };

      return new Response(JSON.stringify(responseData), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data, error } = await supabase
      .from("users")
      .update({ strigaUserId: strigaResponseBody.userId })
      .eq("id", userId);

    if (error) {
      const responseData = {
        isRequestSuccessfull: false,
        data: null,
        error: error,
      };

      console.log("Supabase update error:", data, error);

      return new Response(JSON.stringify(responseData), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const responseData = {
      isRequestSuccessfull: true,
      data: { strigaResponseBody, data },
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
