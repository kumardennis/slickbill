import express from "express";
import https from "node:https";
import fetch from "node-fetch";
import cors from "cors";
import process from "node:process";
import { CdpClient } from "@coinbase/cdp-sdk";
const cdp = new CdpClient({
    apiKeyId: process.env.CDP_API_KEY_ID || "",
    apiKeySecret: process.env.CDP_API_KEY_SECRET || "",
    walletSecret: process.env.CDP_WALLET_SECRET || "",
});
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
app.post("/cdp/create-or-get-account", async (req, res) => {
    try {
        const { accountName, currency } = req.body;
        console.log(`➡️ Creating CDP account: ${accountName} (${currency})`);
        const account = await cdp.evm.getOrCreateAccount({
            name: accountName,
        });
        console.log("📥 Created account:", account);
        res.status(200).json({ account });
    }
    catch (error) {
        console.error("❌ Error creating account:", error);
        res.status(500).json({
            error: error instanceof Error ? error.message : "An unknown error occurred",
        });
    }
});
// Simple proxy endpoint
app.post("/proxy", async (req, res) => {
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
        console.log("📥 Response (first 500 chars):", responseText.substring(0, 500));
        // Try to parse as JSON, fallback to text
        let data;
        try {
            data = JSON.parse(responseText);
            console.log("✅ Parsed JSON response:", data);
        }
        catch (e) {
            console.log("⚠️ Response is not JSON, returning as text");
            data = responseText;
        }
        res
            .status(response.status)
            .set(Object.fromEntries(response.headers.entries()))
            .send(data);
    }
    catch (error) {
        console.error("❌ Proxy error:", error);
        res.status(500).json({
            error: error instanceof Error ? error.message : "An unknown error occurred",
        });
    }
});
app.listen(PORT, () => {
    console.log(`Proxy server running on port ${PORT}`);
});
export default app;
