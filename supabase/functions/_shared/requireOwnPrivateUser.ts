import { corsHeaders } from "./cors.ts";
import { createSupabase, createSupabaseService } from "./supabaseClient.ts";

function jsonError(status: number, error: string) {
  return new Response(
    JSON.stringify({
      isRequestSuccessfull: false,
      data: null,
      error,
    }),
    {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    },
  );
}

/** Confirm JWT user owns this private_users.id, then return a service-role client. */
export async function requireOwnPrivateUser(
  req: Request,
  privateUserId: unknown,
) {
  const requestedId = typeof privateUserId === "number"
    ? privateUserId
    : Number.parseInt(String(privateUserId ?? ""), 10);

  const authClient = createSupabase(req);
  const { data: authData, error: authError } = await authClient.auth.getUser();
  if (authError || !authData.user || !Number.isFinite(requestedId)) {
    return {
      ok: false as const,
      response: jsonError(401, "Not authenticated"),
      service: null,
    };
  }

  const service = createSupabaseService();
  const { data: privateUser } = await service
    .from("private_users")
    .select("id, userId")
    .eq("id", requestedId)
    .maybeSingle();

  if (!privateUser) {
    return {
      ok: false as const,
      response: jsonError(403, "Forbidden"),
      service: null,
    };
  }

  const { data: appUser } = await service
    .from("users")
    .select("authUserId")
    .eq("id", privateUser.userId)
    .maybeSingle();

  if (!appUser || appUser.authUserId !== authData.user.id) {
    return {
      ok: false as const,
      response: jsonError(403, "Forbidden"),
      service: null,
    };
  }

  return { ok: true as const, response: null, service };
}
