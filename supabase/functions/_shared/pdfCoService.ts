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
};
