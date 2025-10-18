import {
  ConnInfo,
  Handler,
  serve,
} from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";

import { handler as get_token } from "./get-token/handler.ts";
import { handler as get_consent } from "./get-consent/handler.ts";
import { handler as create_sepa_transfer } from "./create-sepa-transfer/handler.ts";

console.log("Setting up localdev");

const handlers = {
  "get-token": get_token,
  "get-consent": get_consent,
  "create-sepa-transfer": create_sepa_transfer,
} as Record<string, Handler>;

function localdevHandler(req: Request, connInfo: ConnInfo) {
  // This is needed if you're planning to invoke your function from a browser.
  if (req.method === "OPTIONS") {
    return new Response("OK", { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const urlParts = url.pathname.split("/");
  const handlerName = urlParts[urlParts.length - 1];
  const handler = handlers[handlerName];

  console.log(`${handlerName} ${req.url}`);
  console.log(handlers, handler);
  try {
    return handler(req, connInfo);
  } catch (err) {
    console.error(err);
    return new Response(JSON.stringify({ error: err }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  }
}

serve(localdevHandler);
