export const OpenAIService = {
  getExtractedTextFromPdf: async (text: string) => {
    const systemPropmpt =
      'You are data extractor from peice of text. The txt is file converted from pdf. It is an invoice. Please extract me the data for \r\n\r\n1) IBAN\r\n2) Merchant\'s name\r\n3) Total amount\r\n4) Due date\r\n5) Very short description\r\n6) Invoice number\r\n7) reference number (viitenumber is estonian language)\r\n\r\nThe language of file is estonian.\r\n\r\nFor sender\'s name TRY to find it with "saatja" or "makse saaja which means "sender" in estonian.\r\n\r\nKeywords for merchantName:\r\nsaatja,\r\nsaaja,\r\nmakse saaja\r\n\r\nPlease do not mix up "arve saaja". it means recipient which is not required in ouptut.\r\n\r\nProvide out in JSON format like with keys :\r\niban: array of found ones {iban, bankName}\r\nmerchantName: string\r\ninvoiceNo: string\r\ntotalAmount: number\r\ndueDate: YYYY-MM-DD\r\ndescription: string\r\nreferenceNumber: string';
    const userPrompt = text;

    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${Deno.env.get("OPEN_AI_KEY")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "ft:gpt-3.5-turbo-0613:personal:slickbills-bot:84BDV2wr",
        messages: [
          {
            role: "system",
            content: systemPropmpt,
          },
          {
            role: "user",
            content: userPrompt,
          },
        ],
        temperature: 0.0,
        // max_tokens: 6000,
      }),
    });

    const responseData = await response.json();

    const extractedData = responseData.choices[0].message.content.trim();

    const parsedDataToJSON = JSON.parse(extractedData);

    console.log("EXTRACT: ", parsedDataToJSON);

    return parsedDataToJSON;
  },

  getCategoryOfBill: async (text: string) => {
    const systemPropmpt =
      'You are very good in categorizing descriptions into budget category.\n\nWith the given description in user prompt:\nTranslate it to english.\nCategorize it into one of the FOLLOWING categories.\n\nconst categories= {\n\tFood: "Food",\n\tGroceries: "Groceries",\n\tTransportation: "Transportation",\n\tHealthcare/hygiene: "Healthcare/hygiene",\nEntertainment: "Entertainment",\nUtilities/bills: "Utilities/bills",\nOnline Subscriptions: "Online Subscriptions",\nFitness: "Kids/pets",\nKids/pets: "Kids/pets",\nClothing: "Clothing",\nInsurance: "Insurance",\n}\n\nIt has to be strictly from the above mentioned options. If none found, give out "Miscellanious"\n\nGive output in JSON Format {category: ""}';
    const userPrompt = text;

    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${Deno.env.get("OPEN_AI_KEY")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4",
        messages: [
          {
            role: "system",
            content: systemPropmpt,
          },
          {
            role: "user",
            content: userPrompt,
          },
        ],
        temperature: 0.0,
        // max_tokens: 6000,
      }),
    });

    const responseData = await response.json();

    const extractedData = responseData.choices[0].message.content.trim();

    const parsedDataToJSON = JSON.parse(extractedData);

    console.log("CATEGORY: ", parsedDataToJSON);

    return parsedDataToJSON.category;
  },

  getCategoryOfTicket: async (text: string) => {
    const systemPropmpt =
      'The following are categories for ticket classification: Boarding Passes, Movie/Theater, Concert/Event, Transportation, Festival Passes, Conference Passes/Badges, Museum/Park Passes, Sports Event, Parking Passes. The assistant will categorize the text extracted from a PDF ticket into one of these categories.\r\nGive output in JSON format :\r\n\r\n{\r\n"category": string,\r\n"dateOfActivity": YYYY-MM-DD,\r\n"Description": string (max 10 words)\r\n"Title": string (max 4 words)\r\n}';
    const userPrompt = `I have text extracted from a PDF ticket and I need to categorize it into one of the predefined categories. The text is: ${text}`;

    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${Deno.env.get("OPEN_AI_KEY")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4",
        messages: [
          {
            role: "system",
            content: systemPropmpt,
          },
          {
            role: "user",
            content: userPrompt,
          },
        ],
        temperature: 0.0,
        // max_tokens: 6000,
      }),
    });

    const responseData = await response.json();

    const extractedData = responseData.choices[0].message.content.trim();

    const parsedDataToJSON = JSON.parse(extractedData);

    console.log("CATEGORY: ", parsedDataToJSON);

    return parsedDataToJSON.category;
  },
};
