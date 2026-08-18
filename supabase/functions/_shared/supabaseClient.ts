import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "./cors.ts";
import { Database } from "./types.ts";

export const createSupabase = (req: Request) =>
  createClient<Database>(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    {
      global: {
        headers: {
          ...corsHeaders,
          Authorization: req.headers.get("Authorization")!,
        },
      },
    },
  );

export const createSupabaseService = () =>
  createClient<Database>(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

export const isServiceRoleRequest = (req: Request): boolean => {
  const auth = req.headers.get("Authorization") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const cronSecret = Deno.env.get("CRON_SECRET") ?? "";
  const providedCron = req.headers.get("x-cron-secret") ?? "";

  if (serviceKey && auth === `Bearer ${serviceKey}`) return true;
  if (cronSecret && (auth === `Bearer ${cronSecret}` || providedCron === cronSecret)) {
    return true;
  }
  return false;
};
