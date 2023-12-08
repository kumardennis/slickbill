import { PostgrestError } from "https://esm.sh/v96/@supabase/postgrest-js@1.0.0-rc.6/dist/module/types.d.ts";

export interface ResponseModel {
  isRequestSuccessful: boolean;
  // deno-lint-ignore no-explicit-any
  data: any | null;
  error: PostgrestError | null | string;
}
