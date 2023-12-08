// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

import {
  User,
} from "https://esm.sh/v96/@supabase/gotrue-js@2.16.0/dist/module/index.d.ts";
import {
  confirmedRequiredParams,
  errorResponseData,
} from "../../_shared/confirmedRequiredParams.ts";
import { corsHeaders } from "../../_shared/cors.ts";
import { createSupabase } from "../../_shared/supabaseClient.ts";

interface CreateUserStudentResponseModel {
  isRequestSuccessfull: boolean;
  error: any;
  data:
    | {
      createdStudentUserData: User | null;
      createdStudentRecordData: any[] | null;
    }
    | { user: User | null }
    | null;
}

export const handler = async (req: Request) => {
  const supabase = createSupabase(req);

  try {
    const {
      email,
      password,
      firstName,
      lastName,
      fullName,
      publicName,
      username,
      isPrivateUser,
      iban,
      accountHolder,
    } = await req
      .json();

    if (
      !confirmedRequiredParams([
        email,
        password,
        isPrivateUser,
        iban,
        accountHolder,
        username,
      ])
    ) {
      return new Response(JSON.stringify(errorResponseData), {
        headers: { "Content-Type": "application/json" },
      });
    }

    /* Check if username is available */
    const { data: usernameData, error: usernameError } = await supabase
      .from("users")
      .select().match({ username });

    if (
      usernameData === undefined || usernameData?.length === undefined ||
      usernameData?.length > 0
    ) {
      const responseData: CreateUserStudentResponseModel = {
        isRequestSuccessfull: false,
        data: null,
        error: "username already taken :(",
      };

      return new Response(JSON.stringify(responseData), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data, error } = await supabase.auth.signUp({
      email,
      password,
    });

    if (error !== null) {
      const responseData: CreateUserStudentResponseModel = {
        isRequestSuccessfull: false,
        data: data,
        error: error,
      };

      return new Response(JSON.stringify(responseData), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: userData, error: userError } = await supabase
      .from("users").insert({
        username,
        email,
        authUserId: data.user?.id,
      })
      .select();

    if (userData === null) {
      const responseData: CreateUserStudentResponseModel = {
        isRequestSuccessfull: false,
        data: userData,
        error: userError,
      };

      return new Response(JSON.stringify(responseData), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (isPrivateUser) {
      const { data: privateUserData, error: privateUserError } = await supabase
        .from("private_users").insert({
          firstName,
          lastName,
          userId: userData[0].id,
          iban,
          bankAccountName: accountHolder,
        })
        .select();

      const responseData = {
        isRequestSuccessfull: privateUserError === null,
        data: privateUserData,
        error: privateUserError,
      };

      return new Response(JSON.stringify(responseData), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    } else {
      const { data: businessUserData, error: businessUserError } =
        await supabase
          .from("business_users").insert({
            fullName,
            publicName,
            userId: userData[0].id,
          })
          .select();

      const responseData = {
        isRequestSuccessfull: businessUserError === null,
        data: businessUserData,
        error: businessUserError,
      };

      return new Response(JSON.stringify(responseData), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
  } catch (err) {
    const responseData: CreateUserStudentResponseModel = {
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
