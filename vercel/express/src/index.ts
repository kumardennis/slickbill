import express from "express";
import https from "node:https";
import fetch from "node-fetch";
import cors from "cors";
import process from "node:process";

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json({ limit: "50mb" }));
app.use(express.urlencoded({ extended: true, limit: "50mb" }));
app.use(express.text());

// Create HTTPS agent with client certificates
const httpsAgent = new https.Agent({
  cert: process.env.LHV_CERT_CONTENT,
  key: process.env.LHV_KEY_CONTENT,
});

app.get("/", (req, res) => {
  res.send("Proxy server is running");
});

// Simple proxy endpoint
app.post("/proxy", async (req: any, res: any) => {
  try {
    console.log("BODY:", req.body);

    const { url, method, headers, body } = req.body;

    console.log(`➡️ Proxying request to: ${url}`);

    const response = await fetch(url, {
      method,
      headers,
      ...(body && {
        body: typeof body === "string" ? body : JSON.stringify(body),
      }),
      agent: httpsAgent,
    });

    // Get response as text first
    const responseText = await response.text();
    console.log(
      "📥 Response (first 500 chars):",
      responseText.substring(0, 500)
    );

    // Try to parse as JSON, fallback to text
    let data;
    try {
      data = JSON.parse(responseText);
      console.log("✅ Parsed JSON response:", data);
    } catch (e) {
      console.log("⚠️ Response is not JSON, returning as text");
      data = responseText;
    }

    res
      .status(response.status)
      .set(Object.fromEntries(response.headers.entries()))
      .send(data);
  } catch (error) {
    console.error("❌ Proxy error:", error);
    res.status(500).json({
      error:
        error instanceof Error ? error.message : "An unknown error occurred",
    });
  }
});

app.listen(PORT, () => {
  console.log(`Proxy server running on port ${PORT}`);
});

export default app;
