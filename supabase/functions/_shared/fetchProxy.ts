export async function fetchProxy(
  options: ProxyRequest = {
    url: "",
    method: "GET",
    headers: {},
    body: undefined,
  }
): Promise<Response> {
  const proxyUrl = "https://express-ten-xi.vercel.app";

  const response = await fetch(`${proxyUrl}/proxy`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: options ? JSON.stringify(options) : undefined,
  });
  return response;
}

export type ProxyRequest = {
  url: string;
  method: string;
  headers: Record<string, string>;
  body?: any | null;
};
