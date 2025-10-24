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
    const { userId } = await req.json();

    if (!confirmedRequiredParams([userId])) {
      return new Response(JSON.stringify(errorResponseData), {
        headers: { "Content-Type": "application/json" },
      });
    }
    // fetch all wallets

    const bodyWallets = {
      startDate: Date.parse("2024-01-01"),
      endDate: Date.now(),
      page: 1,
    };

    console.log(calcStrigaAuthSign(bodyWallets, "/ping", "POST"));

    const strigaFetchOptionWallets = {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: calcStrigaAuthSign(bodyWallets, "/ping", "POST"),
        "api-key": SANDBOX_API_KEY,
      },
      body: JSON.stringify(bodyWallets),
    };

    const strigaWalletsResponse = await fetch(
      "https://www.sandbox.striga.com/api/v1/ping",
      strigaFetchOptionWallets
    );

    const strigaWalletsResponseBody = await strigaWalletsResponse.json();

    const responseData = {
      isRequestSuccessfull: true,
      data: { strigaWalletsResponseBody },
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
