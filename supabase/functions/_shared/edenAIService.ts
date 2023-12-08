const baseUrl = "https://api.edenai.run/v2/ocr";

const invoiceParseUrl = `${baseUrl}/invoice_parser`;
const receiptParseUrl = `${baseUrl}/receipt_parser`;
const customDocParseUrl = `${baseUrl}/custom_document_parsing_async`;

export const EdenAIService = {
  getExtractedInvoiceData: async (file: Blob) => {
    const formData = new FormData();

    console.log(typeof file);

    formData.append("file", file);

    // formData.append('language', null)
    formData.append("providers", "google, affinda");
    formData.append("response_as_dict", "true");
    formData.append("attributes_as_list", "false");
    formData.append("show_original_response", "false");

    const response = await fetch(invoiceParseUrl, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${Deno.env.get("EDEN_AI_APIKEY")}`,
      },
      body: (formData),
    });

    const jsonResponse = response.json();

    return jsonResponse;
  },

  getExtractedReceiptData: async (file: Blob) => {
    const formData = new FormData();

    console.log(typeof file);

    formData.append("language", "auto-detect");

    formData.append("file", file);

    formData.append("response_as_dict", "true");
    formData.append("attributes_as_list", "false");
    formData.append("show_original_response", "false");
    formData.append("providers", "veryfi");

    const response = await fetch(receiptParseUrl, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${Deno.env.get("EDEN_AI_APIKEY")}`,
      },
      body: formData,
    });

    console.log(response);

    const jsonResponse = await response.json();

    console.log("FORM: ", formData);
    console.log("RESPOND EDEN: ", jsonResponse);

    return jsonResponse;
  },

  createJobInvoiceCustomFields: async (file: Blob) => {
    const formData = new FormData();

    console.log(typeof file);

    formData.append("file", file);

    // formData.append('language', null)

    formData.append("providers", "amazon");
    formData.append("response_as_dict", "true");
    formData.append("attributes_as_list", "false");
    formData.append("show_original_response", "false");
    formData.append(
      "queries",
      `[ { "query": "viitenumber", "pages": "1-*" } ]`,
    );

    const response = await fetch(customDocParseUrl, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${Deno.env.get("EDEN_AI_APIKEY")}`,
      },
      body: formData,
    });

    const jsonResponse = response.json();

    return jsonResponse;
  },

  getExtractedInvoiceCustomFields: async (id: string) => {
    const getCustomDocParseUrl =
      `${customDocParseUrl}/${id}?response_as_dict=true&show_original_response=false`;

    const response = await fetch(getCustomDocParseUrl, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${Deno.env.get("EDEN_AI_APIKEY")}`,
      },
    });

    const jsonResponse = response.json();

    return jsonResponse;
  },
};
