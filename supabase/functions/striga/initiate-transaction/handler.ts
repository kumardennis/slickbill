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
    const { userId, destinationUserId, memo, amount } = await req.json();

    if (!confirmedRequiredParams([userId])) {
      return new Response(JSON.stringify(errorResponseData), {
        headers: { "Content-Type": "application/json" },
      });
    }

    const { data: userData, error: userError } = await supabase
      .from("users")
      .select("strigaUserId, strigaWalletId")
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

    const { data: destinationData, error: destinationError } = await supabase
      .from("users")
      .select("strigaUserId, strigaWalletId")
      .eq("id", destinationUserId);

    if (destinationError) {
      const responseData = {
        isRequestSuccessfull: false,
        data: null,
        error: destinationError,
      };

      return new Response(JSON.stringify(responseData), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // fetch all wallets

    const bodyWallets = {
      userId: userData?.[0]?.strigaUserId,
      walletId: userData?.[0]?.strigaWalletId,
    };

    const bodyDestinationWallets = {
      userId: destinationData?.[0]?.strigaUserId,
      walletId: destinationData?.[0]?.strigaWalletId,
    };

    const strigaFetchOptionWallets = {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: calcStrigaAuthSign(bodyWallets, "/wallets/get", "POST"),
        "api-key": SANDBOX_API_KEY,
      },
      body: JSON.stringify(bodyWallets),
    };

    const strigaFetchOptionDestinationWallets = {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: calcStrigaAuthSign(
          bodyDestinationWallets,
          "/wallets/get",
          "POST"
        ),
        "api-key": SANDBOX_API_KEY,
      },
      body: JSON.stringify(bodyDestinationWallets),
    };

    const strigaWalletsResponse = await fetch(
      "https://www.sandbox.striga.com/api/v1/wallets/get",
      strigaFetchOptionWallets
    );

    const destinationStrigaWalletsResponse = await fetch(
      "https://www.sandbox.striga.com/api/v1/wallets/get",
      strigaFetchOptionDestinationWallets
    );

    const strigaWalletsResponseBody = await strigaWalletsResponse.json();
    const destinationStrigaWalletsResponseBody =
      await destinationStrigaWalletsResponse.json();

    // then initiate payment

    const body = {
      userId: userData?.[0]?.strigaUserId,
      sourceAccountId: strigaWalletsResponseBody.accounts["EUR"].accountId,
      destinationAccountId:
        destinationStrigaWalletsResponseBody.accounts["EUR"].accountId,
      amount,
      memo,
    };

    const strigaFetchOption = {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: calcStrigaAuthSign(
          body,
          "/wallets/send/intra/initiate",
          "POST"
        ),
        "api-key": SANDBOX_API_KEY,
      },
      body: JSON.stringify(body),
    };

    const strigaResponse = await fetch(
      "https://www.sandbox.striga.com/api/v1/wallets/send/intra/initiate",
      strigaFetchOption
    );

    const strigaResponseBody = await strigaResponse.json();

    console.log(strigaResponseBody);

    const responseData = {
      isRequestSuccessfull: true,
      data: { strigaResponseBody },
      error: null,
    };

    return new Response(JSON.stringify(responseData), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.log(err);
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
