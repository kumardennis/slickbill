// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

import {
  confirmedRequiredParams,
  errorResponseData,
} from "../../_shared/confirmedRequiredParams.ts";
import { corsHeaders } from "../../_shared/cors.ts";
import { Consent } from "../../_shared/tppBanks/consentStrategies/index.ts";
import { Token } from "../../_shared/tppBanks/tokenStrategies/index.ts";

export const handler = async (req: Request) => {
  const { token, bankName } = await req.json();

  if (!confirmedRequiredParams([token, bankName])) {
    return new Response(JSON.stringify(errorResponseData), {
      headers: { "Content-Type": "application/json" },
    });
  }

  const consentStrategy = new Consent(token, bankName);

  try {
    await consentStrategy.createConsent();
    const token = consentStrategy.getConsentId();

    const responseData = {
      isRequestSuccessfull: true,
      data: { token },
      error: null,
    };

    return new Response(JSON.stringify(responseData), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    const responseData = {
      isRequestSuccessfull: false,
      data: null,
      error: { err },
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
