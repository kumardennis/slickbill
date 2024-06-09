const baseUrl = "https://api.pdf.co/v1";

export const PdfCoService = {
  scanBarcodeOrQRFromPdf: async (fileUrl: string) => {
    const response = await fetch(`${baseUrl}/barcode/read/from/url`, {
      method: "POST",
      headers: {
        "x-api-key": `Bearer ${Deno.env.get("PDF_CO_KEY")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        url: fileUrl,
        types: "QRCode,Code128,Code39,Interleaved2of5,EAN13",
        pages: "0",
        async: false,
      }),
    });

    const responseData = await response.json();

    const extractedData = responseData.choices[0].message.content.trim();

    const parsedDataToJSON = JSON.parse(extractedData);

    console.log("EXTRACT: ", parsedDataToJSON);

    return parsedDataToJSON;
  },

  generateQRCode: async (fileUrl: string) => {
    const response = await fetch(`${baseUrl}/barcode/generate`, {
      method: "POST",
      headers: {
        "x-api-key": `Bearer ${Deno.env.get("PDF_CO_KEY")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        url: fileUrl,
        types: "QRCode,Code128,Code39,Interleaved2of5,EAN13",
        pages: "0",
        async: false,
      }),
    });

    const responseData = await response.json();

    const extractedData = responseData.choices[0].message.content.trim();

    const parsedDataToJSON = JSON.parse(extractedData);

    console.log("EXTRACT: ", parsedDataToJSON);

    return parsedDataToJSON;
  },

  uploadFileTemporary: async (fileBytes: Uint8Array, privateUserId: number) => {
    const getPresignedUrlToUploadToResponse = await fetch(
      `${baseUrl}/file/upload/get-presigned-url?name=temporary_file_slickbills_${privateUserId}_${Date.now()}`,
      {
        method: "GET",
        headers: {
          "x-api-key": `Bearer ${Deno.env.get("PDF_CO_KEY")}`,
          "Content-Type": "application/pdf",
        },
      }
    );

    const getPresignedUrlToUploadToJSON =
      await getPresignedUrlToUploadToResponse.json();

    const uploadFileResponse = await fetch(
      `${getPresignedUrlToUploadToJSON.presignedUrl}`,
      {
        method: "PUT",
        headers: {
          "x-api-key": `Bearer ${Deno.env.get("PDF_CO_KEY")}`,
          "Content-Type": "application/octet-stream",
        },
        body: JSON.stringify({
          "data-binary": fileBytes,
        }),
      }
    );

    const responseData = await uploadFileResponse.json();

    const tempraryUrl = responseData.url;

    console.log("TEMPURI: ", responseData);

    return tempraryUrl;
  },
};
