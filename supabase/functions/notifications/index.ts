import {
  ConnInfo,
  Handler,
  serve,
} from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";

import { handler as send_notification } from "./send-notification/handler.ts";

console.log("Setting up notifications");

const handlers = {
  "send-notification": send_notification,
};

const apiHandler: Handler = async (req, connInfo) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const path = url.pathname.split("/").pop();

  const handler = handlers[path as keyof typeof handlers];

  if (!handler) {
    return new Response(`No handler found for ${path}`, {
      status: 404,
      headers: corsHeaders,
    });
  }

  return handler(req);
};

serve(apiHandler);
