import {
  ConnInfo,
  Handler,
  serve,
} from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";

import { handler as get_ticket_brief_data } from "./get-ticket-brief-data/handler.ts";
import { handler as get_private_user_tickets } from "./get-private-user-tickets/handler.ts";
import { handler as create_private_user_ticket } from "./create-private-user-ticket/handler.ts";

console.log("Setting up localdev");

const handlers = {
  "get-ticket-brief-data": get_ticket_brief_data,
  "get-private-user-tickets": get_private_user_tickets,
  "create-private-user-ticket": create_private_user_ticket,
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
  try {
    return handler(req, connInfo);
  } catch (err) {
    return new Response(JSON.stringify({ error: err }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  }
}

serve(localdevHandler);
