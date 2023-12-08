// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

import {
  User,
} from "https://esm.sh/v96/@supabase/gotrue-js@2.16.0/dist/module/index.d.ts";
import { base64ToBlob } from "../../_shared/base64ToBlob.ts";
import {
  confirmedRequiredParams,
  errorResponseData,
} from "../../_shared/confirmedRequiredParams.ts";
import { corsHeaders } from "../../_shared/cors.ts";
import { EdenAIService } from "../../_shared/edenAIService.ts";
import { OpenAIService } from "../../_shared/openAIService.ts";
import { createSupabase } from "../../_shared/supabaseClient.ts";
import { urlBase64ToBlob } from "../../_shared/urlBase64ToBlob.ts";

export const handler = async (req: Request) => {
  const supabase = createSupabase(req);

  try {
    const { supabaseStorageUrl } = await req.json();

    // const form = await req.formData();

    // const fileBlob = form.get("image");
    // // const mimeType = form.get("fileMimeType");

    if (
      !confirmedRequiredParams([
        supabaseStorageUrl,
      ])
    ) {
      return new Response(JSON.stringify(errorResponseData), {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json; charset=utf-8",
        },
      });
    }

    const fileResponse = await supabase.storage.from("temporary-files")
      .download(
        supabaseStorageUrl.split("/")[1],
      );
    const fileBlob = fileResponse.data;

    if (!fileBlob) {
      const responseData = {
        isRequestSuccessfull: false,
        data: null,
        error: "File is not blob",
      };

      return new Response(JSON.stringify(responseData), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const fileName = "myFile.jpg";
    const file = new Blob([fileBlob], { type: fileBlob.type });

    const convertedFile = new File([file], fileName, {
      type: fileBlob.type,
      lastModified: new Date().getTime(),
    });

    if (convertedFile instanceof Blob) {
      const response = await EdenAIService.getExtractedReceiptData(
        convertedFile,
      );

      const categoryResponse = await OpenAIService.getCategoryOfBill(
        response["veryfi"]["extracted_data"][0]["category"],
      );

      const responseData = {
        isRequestSuccessfull: true,
        data: { ...response, category: categoryResponse },
        error: null,
      };

      return new Response(JSON.stringify(responseData), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    } else {
      const responseData = {
        isRequestSuccessfull: false,
        data: null,
        error: "File is not blob",
      };

      return new Response(JSON.stringify(responseData), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
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
