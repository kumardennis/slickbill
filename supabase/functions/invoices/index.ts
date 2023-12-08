import {
  ConnInfo,
  Handler,
  serve,
} from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";

import { handler as create_private_user_invoice } from "./create-private-user-invoice/handler.ts";
import { handler as create_private_group_invoice } from "./create-private-group-invoice/handler.ts";
import { handler as get_receipt_extracted_data } from "./get-receipt-extracted-data/handler.ts";
import { handler as get_invoice_custom_fields } from "./get-invoice-custom-fields/handler.ts";
import { handler as create_private_user_self_invoice } from "./create-private-user-self-invoice/handler.ts";
import { handler as get_private_user_sent_invoices } from "./get-private-user-sent-invoices/handler.ts";
import { handler as get_private_group_sent_invoices } from "./get-private-group-sent-invoices/handler.ts";
import { handler as get_private_user_received_invoices } from "./get-private-user-received-invoices/handler.ts";
import { handler as get_private_user_sent_obsolete_invoices } from "./get-private-user-sent-obsolete-invoices/handler.ts";
import { handler as get_private_user_received_obsolete_invoices } from "./get-private-user-received-obsolete-invoices/handler.ts";
import { handler as update_invoice_status } from "./update-invoice-status/handler.ts";
import { handler as update_invoice_obsolete } from "./update-invoice-obsolete/handler.ts";
import { handler as get_ticket_brief_data } from "./get-ticket-brief-data/handler.ts";

console.log("Setting up localdev");

const handlers = {
  "create-private-user-invoice": create_private_user_invoice,
  "create-private-group-invoice": create_private_group_invoice,
  "create-private-user-self-invoice": create_private_user_self_invoice,
  "get-receipt-extracted-data": get_receipt_extracted_data,
  "get-invoice-custom-fields": get_invoice_custom_fields,
  "get-private-user-sent-invoices": get_private_user_sent_invoices,
  "get-private-group-sent-invoices": get_private_group_sent_invoices,
  "get-private-user-received-invoices": get_private_user_received_invoices,
  "get-private-user-sent-obsolete-invoices":
    get_private_user_sent_obsolete_invoices,
  "get-private-user-received-obsolete-invoices":
    get_private_user_received_obsolete_invoices,
  "update-invoice-status": update_invoice_status,
  "update-invoice-obsolete": update_invoice_obsolete,
  "get-ticket-brief-data": get_ticket_brief_data,
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
