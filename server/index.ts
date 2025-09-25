import express from "express";
import https from "node:https";
import fetch from "node-fetch";
import cors from "cors";
import process from "node:process";

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

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
    const { url, method, headers, body } = req.body;

    const response = await fetch(url, {
      method,
      headers,
      body: body ? JSON.stringify(body) : undefined,
      agent: httpsAgent,
    });

    const data = await response.json();
    console.log("✅ Response data:", data);

    res
      .status(response.status)
      .set(Object.fromEntries(response.headers.entries()))
      .send(data);
  } catch (error) {
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
