import {
  ConnInfo,
  Handler,
  serve,
} from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";

import { handler as create_user } from "./create-user/handler.ts";
import { handler as update_user } from "./update-user/handler.ts";
import { handler as start_kyc } from "./start-kyc/handler.ts";
import { handler as get_wallets } from "./get-wallets/handler.ts";
import { handler as enrich_account } from "./enrich-account/handler.ts";
import { handler as get_kyc_status } from "./get-kyc-status/handler.ts";
import { handler as initiate_transaction } from "./initiate-transaction/handler.ts";
import { handler as initiate_sepa_transaction } from "./initiate-sepa-transaction/handler.ts";
import { handler as confirm_transaction } from "./confirm-transaction/handler.ts";
import { handler as ping } from "./ping/handler.ts";

console.log("Setting up localdev");

const handlers = {
  "create-user": create_user,
  "update-user": update_user,
  "start-kyc": start_kyc,
  "get-wallets": get_wallets,
  "enrich-account": enrich_account,
  "get-kyc-status": get_kyc_status,
  "initiate-transaction": initiate_transaction,
  "initiate-sepa-transaction": initiate_sepa_transaction,
  "confirm-transaction": confirm_transaction,
  ping: ping,
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
