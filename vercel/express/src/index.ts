declare global {
  interface BigInt {
    toJSON(): string;
  }
}

type ExchangeEntry = {
  token: string;
  expiresAt: number;
};

BigInt.prototype.toJSON = function () {
  return this.toString();
};

import dotenv from "dotenv";
dotenv.config();

import express from "express";
import https from "node:https";
import fetch from "node-fetch";
import cors from "cors";
import process, { debugPort } from "node:process";
import { CdpClient } from "@coinbase/cdp-sdk";
import { generateJwt } from "@coinbase/cdp-sdk/auth";
import { parseUnits } from "viem";
import crypto from "node:crypto";

console.log("🔍 Environment variables:");
console.log(
  "CDP_API_KEY_ID:",
  process.env.CDP_API_KEY_ID ? "✅ Set" : "❌ Missing"
);
console.log(
  "CDP_API_KEY_SECRET:",
  process.env.CDP_API_KEY_SECRET ? "✅ Set" : "❌ Missing"
);
console.log(
  "CDP_WALLET_SECRET:",
  process.env.CDP_WALLET_SECRET ? "✅ Set" : "❌ Missing"
);

const cdp = new CdpClient({
  apiKeyId: process.env.CDP_API_KEY_ID || "",
  apiKeySecret: process.env.CDP_API_KEY_SECRET || "",
  walletSecret: process.env.CDP_WALLET_SECRET || "",
});

const app = express();
const PORT = process.env.PORT || 3000;

const exchangeCodeStore = new Map<string, ExchangeEntry>();

const eurcContractAddress = "0x808456652fdb597867f38412077A9182bf77359F"; // EURC contract address on Base

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

app.post("/cdp/get-account", async (req: any, res: any) => {
  try {
    const { accountName, currency } = req.body;

    console.log(`➡️ Getting CDP account: ${accountName} (${currency})`);

    const account = await cdp.evm.getAccount({
      name: accountName,
    });

    const smartAccount = await cdp.evm.getOrCreateSmartAccount({
      owner: account,
      name: accountName,
    });

    console.log("📥 Got account:", smartAccount);

    res.status(200).json({ smartAccount });
  } catch (error) {
    console.error("❌ Error getting account:", error);
    res.status(500).json({
      error:
        error instanceof Error ? error.message : "An unknown error occurred",
    });
  }
});

app.post("/cdp/create-or-get-account", async (req: any, res: any) => {
  try {
    const { accountName, currency } = req.body;

    console.log(`➡️ Creating CDP account: ${accountName} (${currency})`);

    const account = await cdp.evm.getOrCreateAccount({
      name: accountName,
    });

    const smartAccount = await cdp.evm.getOrCreateSmartAccount({
      owner: account,
      name: accountName,
    });

    console.log("📥 Created account:", smartAccount);

    res.status(200).json({ smartAccount });
  } catch (error) {
    console.error("❌ Error creating account:", error);
    res.status(500).json({
      error:
        error instanceof Error ? error.message : "An unknown error occurred",
    });
  }
});

app.post("/cdp/request-testnet-faucet", async (req: any, res: any) => {
  try {
    const { accountName } = req.body;

    console.log(`➡️ CDP account: ${accountName}`);

    const account = await cdp.evm.getAccount({
      name: accountName,
    });

    const smartAccount = await cdp.evm.getOrCreateSmartAccount({
      owner: account,
      name: accountName,
    });

    console.log("📥 Got account:", smartAccount);

    const faucetResp = await cdp.evm.requestFaucet({
      address: smartAccount.address,
      network: "base-sepolia",
      token: "eurc",
    });

    console.log("📥 Got faucet response:", faucetResp);

    res.status(200).json({ faucetResp });
  } catch (error) {
    console.error("❌ Error creating account:", error);
    res.status(500).json({
      error:
        error instanceof Error ? error.message : "An unknown error occurred",
    });
  }
});

app.post("/cdp/get-balances", async (req: any, res: any) => {
  try {
    const { accountName } = req.body;

    console.log(`➡️ CDP account: ${accountName}`);

    const account = await cdp.evm.getAccount({
      name: accountName,
    });

    const smartAccount = await cdp.evm.getOrCreateSmartAccount({
      owner: account,
      name: accountName,
    });

    console.log("📥 Got account:", smartAccount);

    const balances = await smartAccount.listTokenBalances({
      network: "base-sepolia",
    });

    console.log("📥 Got balances response:", balances);

    const parsedBalances = {
      balances: balances.balances.map((balance: any) => {
        const rawAmount = BigInt(balance.amount.amount);
        const decimals = balance.amount.decimals;

        const humanReadable = Number(rawAmount) / Math.pow(10, decimals);

        console.log(
          `Token: ${
            balance.token.symbol
          }, Raw Amount: ${rawAmount}, Human Readable: ${humanReadable.toFixed(
            decimals
          )}`
        );

        return {
          token: {
            symbol: balance.token.symbol,
            contractAddress: balance.token.contractAddress,
          },
          amount: {
            raw: BigInt(balance.amount.amount).toString(),
            decimals: decimals,
            formatted: humanReadable.toFixed(decimals),
          },
        };
      }),
      nextPageToken: balances.nextPageToken,
    };

    res.status(200).json(parsedBalances);
  } catch (error) {
    console.error("❌ Error getting balances:", error);
    res.status(500).json({
      error:
        error instanceof Error ? error.message : "An unknown error occurred",
    });
  }
});

app.post("/cdp/send-payment", async (req: any, res: any) => {
  try {
    const { fromAccountName, toAccountName, amountEurc } = req.body;

    console.log(
      `➡️ CDP account: ${fromAccountName} -> ${toAccountName} ${typeof amountEurc} ${amountEurc} EURC`
    );

    const sender = await cdp.evm.getAccount({
      name: fromAccountName,
    });

    const smartAccount = await cdp.evm.getOrCreateSmartAccount({
      owner: sender,
      name: fromAccountName,
    });

    const receiver = await cdp.evm.getAccount({
      name: toAccountName,
    });

    const receiverSmartAccount = await cdp.evm.getOrCreateSmartAccount({
      owner: receiver,
      name: toAccountName,
    });

    const erc20Abi = [
      {
        name: "transfer",
        type: "function",
        inputs: [
          { name: "to", type: "address" },
          { name: "amount", type: "uint256" },
        ],
        outputs: [{ type: "bool" }],
      },
    ] as const;

    const result = await smartAccount.transfer({
      to: receiverSmartAccount.address,
      amount: parseUnits(amountEurc.toString(), 6),
      token: eurcContractAddress,
      network: "base-sepolia",
    });

    console.log("📥 Got payment response:", result);

    res.status(200).json(result);
  } catch (error) {
    console.error("❌ Error sending payment:", error);
    res.status(500).json({
      error:
        error instanceof Error ? error.message : "An unknown error occurred",
    });
  }
});

app.post("/cdp/create-onramp-session", async (req: any, res: any) => {
  try {
    const { accountName } = req.body;

    console.log(`➡️ Creating onramp session for CDP account: ${accountName}`);

    // ✅ Get client IP from request headers or body
    const clientIp =
      req.body.clientIp || // Use provided IP if testing
      req.headers["x-forwarded-for"]?.split(",")[0].trim() || // Proxy IP
      req.headers["x-real-ip"] || // Nginx
      req.ip || // Express default
      req.connection.remoteAddress; // Fallback

    console.log(`🌐 Client IP detected: ${clientIp}`);

    // ✅ Check if it's a private IP
    const isPrivateIp =
      /^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.|::1|fe80:)/.test(
        clientIp
      );

    if (isPrivateIp) {
      console.warn(
        `⚠️ Private IP detected (${clientIp}), will omit from request`
      );
    }

    const sender = await cdp.evm.getAccount({
      name: accountName,
    });

    const smartAccount = await cdp.evm.getOrCreateSmartAccount({
      owner: sender,
      name: accountName,
    });

    const token = await generateJwt({
      apiKeyId: process.env.CDP_API_KEY_ID!,
      apiKeySecret: process.env.CDP_API_KEY_SECRET!,
      requestMethod: "POST",
      requestHost: "api.cdp.coinbase.com",
      requestPath: "/platform/v2/onramp/sessions",
      expiresIn: 120, // optional (defaults to 120 seconds)
    });

    console.log(
      "📥 Got onramp session token:",
      token,
      "   FOR account address: ",
      smartAccount.address
    );

    const options = {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        purchaseCurrency: "USDC",
        destinationNetwork: "base",
        destinationAddress: smartAccount.address,
        paymentCurrency: "EUR",
        country: "EE",
        redirectUrl: "https://slickbills.com/success",
        // ...(clientIp && !isPrivateIp && { clientIp }),
        partnerUserRef: "user-1234",
      }),
    };

    const response = await fetch(
      "https://api.cdp.coinbase.com/platform/v2/onramp/sessions",
      options
    );

    console.log(
      "📥 Onramp session response status:",
      response,
      response.status,
      response.statusText
    );
    const data = await response.json();

    res.status(200).json(data);
  } catch (error) {
    console.error("❌ Error creating onramp session:", error);
    res.status(500).json({
      error:
        error instanceof Error ? error.message : "An unknown error occurred",
    });
  }
});

app.post("/cdp/get-onramp-session-url", async (req: any, res: any) => {
  try {
    const { address } = req.body;

    console.log(`➡️ Creating onramp session for CDP account: ${address}`);

    // ✅ Get client IP from request headers or body
    const clientIp =
      req.body.clientIp || // Use provided IP if testing
      req.headers["x-forwarded-for"]?.split(",")[0].trim() || // Proxy IP
      req.headers["x-real-ip"] || // Nginx
      req.ip || // Express default
      req.connection.remoteAddress; // Fallback

    console.log(`🌐 Client IP detected: ${clientIp}`);

    // ✅ Check if it's a private IP
    const isPrivateIp =
      /^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.|::1|fe80:)/.test(
        clientIp
      );

    if (isPrivateIp) {
      console.warn(
        `⚠️ Private IP detected (${clientIp}), will omit from request`
      );
    }

    const token = await generateJwt({
      apiKeyId: process.env.CDP_API_KEY_ID!,
      apiKeySecret: process.env.CDP_API_KEY_SECRET!,
      requestMethod: "POST",
      requestHost: "api.cdp.coinbase.com",
      requestPath: "/platform/v2/onramp/sessions",
      expiresIn: 120, // optional (defaults to 120 seconds)
    });

    console.log(
      "📥 Got onramp session token:",
      token,
      "   FOR account address: ",
      address
    );

    const options = {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        purchaseCurrency: "EURC",
        destinationNetwork: "base",
        destinationAddress: address,
        paymentCurrency: "EUR",
        country: "EE",
        redirectUrl: "https://slickbills.com/success",
        // ...(clientIp && !isPrivateIp && { clientIp }),
        partnerUserRef: "user-1234",
      }),
    };

    const response = await fetch(
      "https://api.cdp.coinbase.com/platform/v2/onramp/sessions",
      options
    );

    console.log(
      "📥 Onramp session response status:",
      response,
      response.status,
      response.statusText
    );
    const data = await response.json();

    res.status(200).json(data);
  } catch (error) {
    console.error("❌ Error creating onramp session:", error);
    res.status(500).json({
      error:
        error instanceof Error ? error.message : "An unknown error occurred",
    });
  }
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

app.post("/cdp/exchange-code", async (req: any, res: any) => {
  try {
    const { token } = req.body ?? {};
    if (!token || typeof token !== "string" || token.length < 20) {
      return res.status(400).json({ error: "Missing token" });
    }

    const code = crypto.randomBytes(24).toString("hex");
    exchangeCodeStore.set(code, { token, expiresAt: Date.now() + 60_000 }); // 60 seconds

    return res.status(200).json({ code, expiresInSec: 60 });
  } catch (e: any) {
    return res.status(500).json({ error: e?.message ?? "Internal error" });
  }
});

app.post("/cdp/exchange-code/consume", async (req: any, res: any) => {
  try {
    const { code } = req.body ?? {};
    if (!code || typeof code !== "string") {
      return res.status(400).json({ error: "Missing code" });
    }

    const entry = exchangeCodeStore.get(code);
    if (!entry) return res.status(404).json({ error: "Invalid code" });

    if (Date.now() > entry.expiresAt) {
      exchangeCodeStore.delete(code);
      return res.status(410).json({ error: "Code expired" });
    }

    // one-time use
    exchangeCodeStore.delete(code);

    return res.status(200).json({ token: entry.token });
  } catch (e: any) {
    return res.status(500).json({ error: e?.message ?? "Internal error" });
  }
});

app.listen(PORT, () => {
  console.log(`Proxy server running on port ${PORT}`);
});

export default app;
