// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.
import {
  confirmedRequiredParams,
  errorResponseData,
} from "../../_shared/confirmedRequiredParams.ts";
import { corsHeaders } from "../../_shared/cors.ts";
import { createSupabase } from "../../_shared/supabaseClient.ts";

const MIN_QUERY_LENGTH = 2;
const MAX_RESULTS = 10;

function normalizeUsernameQuery(raw: unknown): string {
  if (typeof raw !== "string") return "";
  return raw.trim().replace(/^@+/, "").toLowerCase();
}

/** Escape % and _ so user input cannot broaden an ilike pattern. */
function escapeIlike(value: string): string {
  return value.replace(/\\/g, "\\\\").replace(/%/g, "\\%").replace(/_/g, "\\_");
}

export const handler = async (req: Request) => {
  const supabase = createSupabase(req);

  try {
    const body = await req.json();
    const { query, excludePrivateUserId } = body ?? {};

    if (!confirmedRequiredParams([query])) {
      return new Response(JSON.stringify(errorResponseData), {
        headers: { "Content-Type": "application/json" },
      });
    }

    const normalized = normalizeUsernameQuery(query);
    if (normalized.length < MIN_QUERY_LENGTH) {
      return new Response(
        JSON.stringify({
          isRequestSuccessfull: true,
          data: [],
          error: null,
        }),
        {
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    const pattern = `${escapeIlike(normalized)}%`;

    // Same join shape as before (private_users → users), prefix match instead of exact eq.
    const { data, error } = await supabase
      .from("private_users")
      .select("id, firstName, lastName, users!inner(username, id)")
      .ilike("users.username", pattern)
      .limit(MAX_RESULTS);

    const excludeId =
      typeof excludePrivateUserId === "number"
        ? excludePrivateUserId
        : Number.parseInt(String(excludePrivateUserId ?? ""), 10);

    const filtered =
      error || !Array.isArray(data)
        ? data
        : data.filter((row: { id: number }) =>
          Number.isFinite(excludeId) ? row.id !== excludeId : true
        );

    const responseData = {
      isRequestSuccessfull: error === null,
      data: filtered,
      error,
    };

    return new Response(JSON.stringify(responseData), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
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
