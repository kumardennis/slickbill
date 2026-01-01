import crypto from "node:crypto";

export const SANDBOX_API_KEY = "sXCz71hSR1jTR3EgmPP1eZJSD-7ry7-3-95keqdMGVk=";
const SANDBOX_API_SECRET = "ULI8ZcuQpG3Z2+IaolV1Uj2IpeXdnjfjTXpgjthOaxo=";

// export const SANDBOX_API_KEY = Deno.env.get("SANDBOX_API_KEY") ?? "";
// const SANDBOX_API_SECRET = Deno.env.get("SANDBOX_API_SECRET") ?? "";

export const calcStrigaAuthSign = (
  body: Record<string, any>,
  testEndpoint: string,
  method: string
) => {
  const hmac = crypto.createHmac("sha256", SANDBOX_API_SECRET);
  const time = Date.now().toString();

  hmac.update(time);
  hmac.update(method);
  hmac.update(testEndpoint);

  const contentHash = crypto.createHash("md5");
  contentHash.update(JSON.stringify(body));

  hmac.update(contentHash.digest("hex"));

  const auth = `HMAC ${time}:${hmac.digest("hex")}`;

  return auth.replace(/\r?\n|\r/g, "").trim();
};
