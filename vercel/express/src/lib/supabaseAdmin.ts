import { createClient } from "@supabase/supabase-js";

type SupabaseAdminClient = ReturnType<typeof createClient>;

let cached: SupabaseAdminClient | null = null;

export const getSupabaseAdmin = (): SupabaseAdminClient | null => {
  const url = process.env.SUPABASE_URL?.trim();
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
  if (!url || !key) {
    return null;
  }
  if (!cached) {
    cached = createClient(url, key, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
  }
  return cached;
};

export const requireSupabaseAdmin = (): SupabaseAdminClient => {
  const client = getSupabaseAdmin();
  if (!client) {
    throw new Error(
      "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required for Monerium settlement.",
    );
  }
  return client;
};
