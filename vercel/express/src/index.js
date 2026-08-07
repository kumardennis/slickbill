BigInt.prototype.toJSON = function () {
    return this.toString();
};
import dotenv from "dotenv";
dotenv.config();
import express from "express";
import https from "node:https";
import fetch from "node-fetch";
import cors from "cors";
import process from "node:process";
import { CdpClient } from "@coinbase/cdp-sdk";
import { generateJwt } from "@coinbase/cdp-sdk/auth";
import { createPublicClient, http, parseAbiItem, parseUnits } from "viem";
import crypto from "node:crypto";
console.log("🔍 Environment variables:");
console.log("CDP_API_KEY_ID:", process.env.CDP_API_KEY_ID ? "✅ Set" : "❌ Missing");
console.log("CDP_API_KEY_SECRET:", process.env.CDP_API_KEY_SECRET ? "✅ Set" : "❌ Missing");
console.log("CDP_WALLET_SECRET:", process.env.CDP_WALLET_SECRET ? "✅ Set" : "❌ Missing");
const cdp = new CdpClient({
    apiKeyId: process.env.CDP_API_KEY_ID || "",
    apiKeySecret: process.env.CDP_API_KEY_SECRET || "",
    walletSecret: process.env.CDP_WALLET_SECRET || "",
});
const app = express();
const PORT = process.env.PORT || 3000;
const exchangeCodeStore = new Map();
const moneriumPkceStore = new Map();
const moneriumTokenStore = new Map();
const rawMoneriumBaseUrl = process.env.MONERIUM_BASE_URL?.trim() || "https://api.monerium.dev";
const moneriumBaseUrl = rawMoneriumBaseUrl.replace(/api\.monrium\.dev/gi, "api.monerium.dev");
if (rawMoneriumBaseUrl !== moneriumBaseUrl) {
    console.warn("⚠️ Corrected MONERIUM_BASE_URL typo", {
        from: rawMoneriumBaseUrl,
        to: moneriumBaseUrl,
    });
}
const moneriumAuthorizePath = process.env.MONERIUM_AUTHORIZE_PATH?.trim() || "/auth";
const moneriumTokenPath = process.env.MONERIUM_TOKEN_PATH?.trim() || "/auth/token";
const moneriumWalletLinkPath = process.env.MONERIUM_WALLET_LINK_PATH?.trim() || "/addresses";
const moneriumIbansPath = process.env.MONERIUM_IBANS_PATH?.trim() || "/ibans";
const moneriumBalancesPath = process.env.MONERIUM_BALANCES_PATH?.trim() || "/balances/{chain}/{address}";
const moneriumRedeemPath = process.env.MONERIUM_REDEEM_PATH?.trim() || "/orders";
const moneriumOrdersPath = process.env.MONERIUM_ORDERS_PATH?.trim() || "/orders";
const configuredMoneriumWalletChain = process.env.MONERIUM_WALLET_CHAIN?.trim() || "";
// SIWE message configuration — must match the values registered in the Monerium developer portal exactly.
const moneriumSiweAppName = process.env.MONERIUM_SIWE_APP_NAME?.trim() ||
    process.env.MONERIUM_APP_NAME?.trim() ||
    "Slickbills";
const moneriumSiweStatement = process.env.MONERIUM_SIWE_STATEMENT?.trim() ||
    `Allow ${moneriumSiweAppName} to access my data on Monerium`;
const moneriumSiwePrivacyUrl = process.env.MONERIUM_PRIVACY_URL?.trim() ||
    "https://slickbills.com/privacy-policy";
const moneriumSiweTermsUrl = process.env.MONERIUM_TERMS_URL?.trim() || "https://slickbills.com/terms";
// EIP-4361 Chain ID for the SIWE message. Can be overridden via env.
// Falls back to a mapping from MONERIUM_WALLET_CHAIN name, then defaults to 137 (Polygon).
const resolveSiweChainId = () => {
    const fromEnv = process.env.MONERIUM_SIWE_CHAIN_ID?.trim();
    if (fromEnv) {
        const parsed = Number(fromEnv);
        if (Number.isFinite(parsed) && parsed > 0)
            return parsed;
    }
    const chainMap = {
        ethereum: 1,
        gnosis: 100,
        polygon: 137,
        "ethereum:sepolia": 11155111,
        "gnosis:chiado": 10200,
        "polygon:amoy": 80002,
    };
    const chainKey = configuredMoneriumWalletChain.toLowerCase();
    if (chainKey && chainMap[chainKey] !== undefined)
        return chainMap[chainKey];
    // Default to Polygon (most common Monerium chain)
    return 137;
};
const moneriumSiweChainId = resolveSiweChainId();
const moneriumHttpTimeoutMs = Number(process.env.MONERIUM_HTTP_TIMEOUT_MS || 15000);
const moneriumLinkVerifyAttempts = Number(process.env.MONERIUM_LINK_VERIFY_ATTEMPTS || 5);
const moneriumLinkVerifyIntervalMs = Number(process.env.MONERIUM_LINK_VERIFY_INTERVAL_MS || 1500);
const moneriumLinkVerifyFetchTimeoutMs = Number(process.env.MONERIUM_LINK_VERIFY_FETCH_TIMEOUT_MS || 5000);
const moneriumClientId = process.env.MONERIUM_CLIENT_ID?.trim() || "";
const moneriumClientSecret = process.env.MONERIUM_CLIENT_SECRET?.trim() || "";
const moneriumScope = process.env.MONERIUM_OAUTH_SCOPE?.trim() || "openid profile offline_access";
const moneriumStateSecret = process.env.MONERIUM_STATE_SECRET?.trim() ||
    moneriumClientSecret ||
    "dev-monerium-state-secret";
const configuredRedirectUri = process.env.MONERIUM_REDIRECT_URI?.trim() || "";
const configuredPublicServerUrl = process.env.PUBLIC_SERVER_URL?.trim() || "";
const moneriumAppAutoRedirectEnabled = process.env.MONERIUM_APP_AUTO_REDIRECT?.trim().toLowerCase() === "true";
const moneriumPkceTtlMs = 10 * 60 * 1000;
const moneriumMonitorRpcUrl = process.env.MONERIUM_MONITOR_RPC_URL?.trim() ||
    process.env.BASE_RPC_URL?.trim() ||
    "";
const moneriumEureTokenAddress = process.env.MONERIUM_EURE_TOKEN_ADDRESS?.trim() ||
    "";
const moneriumMonitorTimeoutMs = Number(process.env.MONERIUM_MONITOR_TIMEOUT_MS || 5000);
const moneriumMonitorPollIntervalMs = Number(process.env.MONERIUM_MONITOR_POLL_INTERVAL_MS || 1000);
const makeMoneriumUrl = (path, query) => {
    const url = new URL(path, moneriumBaseUrl);
    if (query) {
        Object.entries(query).forEach(([k, v]) => {
            if (v !== undefined && v !== null) {
                url.searchParams.set(k, v);
            }
        });
    }
    return url.toString();
};
const resolveMoneriumBalancesPath = (chain, address) => {
    const normalizedChain = chain.trim();
    const normalizedAddress = address.trim();
    if (moneriumBalancesPath.includes("{chain}") ||
        moneriumBalancesPath.includes("{address}")) {
        return moneriumBalancesPath
            .replaceAll("{chain}", encodeURIComponent(normalizedChain))
            .replaceAll("{address}", encodeURIComponent(normalizedAddress));
    }
    const base = moneriumBalancesPath.replace(/\/$/, "");
    return `${base}/${encodeURIComponent(normalizedChain)}/${encodeURIComponent(normalizedAddress)}`;
};
const sleep = (ms) => new Promise((resolve) => {
    setTimeout(resolve, ms);
});
const readMoneriumOrdersArray = (raw) => {
    if (Array.isArray(raw)) {
        return raw.filter((item) => Boolean(item) && typeof item === "object");
    }
    if (!raw || typeof raw !== "object") {
        return [];
    }
    const map = raw;
    const candidates = [map.items, map.results, map.data, map.orders];
    for (const candidate of candidates) {
        if (Array.isArray(candidate)) {
            return candidate.filter((item) => Boolean(item) && typeof item === "object");
        }
    }
    return [];
};
const extractOrderId = (order) => {
    if (typeof order.id === "string" && order.id.trim().length > 0) {
        return order.id.trim();
    }
    if (typeof order.orderId === "string" && order.orderId.trim().length > 0) {
        return order.orderId.trim();
    }
    return "";
};
const monitorMoneriumOrderByTransfer = async (params) => {
    const deadline = Date.now() + moneriumMonitorTimeoutMs;
    const wallet = normalizeEvmAddress(params.walletAddress);
    if (!wallet || !moneriumMonitorRpcUrl || !moneriumEureTokenAddress) {
        // Keep timing consistent: return pending only after timeout, not immediately.
        const remainingMs = Math.max(0, deadline - Date.now());
        if (remainingMs > 0) {
            await sleep(remainingMs);
        }
        return null;
    }
    const transferEvent = parseAbiItem("event Transfer(address indexed from, address indexed to, uint256 value)");
    const client = createPublicClient({
        transport: http(moneriumMonitorRpcUrl),
    });
    const zeroAddress = "0x0000000000000000000000000000000000000000";
    let nextFromBlock = await client.getBlockNumber();
    while (Date.now() < deadline) {
        const latestBlock = await client.getBlockNumber();
        if (latestBlock >= nextFromBlock) {
            const logs = await client.getLogs({
                address: moneriumEureTokenAddress,
                event: transferEvent,
                fromBlock: nextFromBlock,
                toBlock: latestBlock,
            });
            nextFromBlock = latestBlock + 1n;
            for (const log of logs) {
                const from = normalizeEvmAddress(log.args.from);
                const to = normalizeEvmAddress(log.args.to);
                const isWalletInvolved = from === wallet || to === wallet;
                const isMintOrBurn = from === zeroAddress || to === zeroAddress;
                if (!isWalletInvolved || !isMintOrBurn || !log.transactionHash) {
                    continue;
                }
                const ordersRaw = await moneriumApiRequest({
                    userId: params.userId,
                    method: "GET",
                    path: moneriumOrdersPath,
                    query: { txHash: log.transactionHash },
                    tokenOverride: params.tokenOverride,
                });
                for (const order of readMoneriumOrdersArray(ordersRaw)) {
                    if (extractOrderId(order) === params.orderId) {
                        return {
                            txHash: log.transactionHash,
                            order,
                        };
                    }
                }
            }
        }
        await sleep(moneriumMonitorPollIntervalMs);
    }
    return null;
};
const normalizeEvmAddress = (value) => {
    if (typeof value !== "string") {
        return null;
    }
    const raw = value.trim();
    if (!raw) {
        return null;
    }
    const match = raw.match(/0x[a-fA-F0-9]{40}/);
    if (match && match[0]) {
        return match[0].toLowerCase();
    }
    return raw.toLowerCase();
};
const collectAddressCandidates = (entry) => {
    const nestedWallet = entry.wallet && typeof entry.wallet === "object"
        ? entry.wallet
        : null;
    const nestedAccount = entry.account && typeof entry.account === "object"
        ? entry.account
        : null;
    const rawCandidates = [
        entry.address,
        entry.walletAddress,
        entry.owner,
        nestedWallet?.address,
        nestedWallet?.walletAddress,
        nestedAccount?.address,
    ];
    const normalized = [];
    for (const candidate of rawCandidates) {
        const next = normalizeEvmAddress(candidate);
        if (next) {
            normalized.push(next);
        }
    }
    return normalized;
};
const summarizeMoneriumAddressRow = (entry) => {
    if (!entry || typeof entry !== "object") {
        return null;
    }
    const row = entry;
    const wallet = row.wallet && typeof row.wallet === "object"
        ? row.wallet
        : null;
    const account = row.account && typeof row.account === "object"
        ? row.account
        : null;
    return {
        id: typeof row.id === "string" ? row.id : undefined,
        profile: typeof row.profile === "string" ? row.profile : undefined,
        chain: typeof row.chain === "string" ? row.chain : undefined,
        address: normalizeEvmAddress(row.address),
        walletAddress: normalizeEvmAddress(wallet?.address ?? row.walletAddress),
        accountAddress: normalizeEvmAddress(account?.address),
        owner: normalizeEvmAddress(row.owner),
        candidates: collectAddressCandidates(row),
    };
};
const findLinkedMoneriumAddressRow = (data, address) => {
    const target = normalizeEvmAddress(address);
    if (!target) {
        return null;
    }
    const rows = extractMoneriumAddressRows(data);
    for (const entry of rows) {
        if (!entry || typeof entry !== "object") {
            continue;
        }
        const row = entry;
        const candidates = collectAddressCandidates(row);
        if (candidates.includes(target)) {
            return row;
        }
    }
    return null;
};
const isMoneriumAddressLinked = (data, address) => {
    const target = normalizeEvmAddress(address);
    if (!target) {
        return false;
    }
    const rows = extractMoneriumAddressRows(data);
    for (const entry of rows) {
        if (!entry || typeof entry !== "object") {
            continue;
        }
        const row = entry;
        const candidates = collectAddressCandidates(row);
        for (const candidate of candidates) {
            if (candidate === target) {
                return true;
            }
        }
    }
    return false;
};
const randomBase64Url = (bytes = 32) => crypto
    .randomBytes(bytes)
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
const sha256Base64Url = (value) => crypto
    .createHash("sha256")
    .update(value)
    .digest("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
const hmacSha256Base64Url = (value, secret) => crypto
    .createHmac("sha256", secret)
    .update(value)
    .digest("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
const encodeBase64UrlUtf8 = (value) => Buffer.from(value, "utf8")
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
const decodeBase64UrlUtf8 = (value) => {
    const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
    const remainder = normalized.length % 4;
    const padded = remainder === 0 ? normalized : `${normalized}${"=".repeat(4 - remainder)}`;
    return Buffer.from(padded, "base64").toString("utf8");
};
const constantTimeStringEqual = (a, b) => {
    if (a.length !== b.length) {
        return false;
    }
    let mismatch = 0;
    for (let i = 0; i < a.length; i += 1) {
        mismatch |= a.charCodeAt(i) ^ b.charCodeAt(i);
    }
    return mismatch === 0;
};
const createMoneriumStateToken = (entry) => {
    const payload = {
        v: 1,
        userId: entry.userId,
        email: entry.email,
        walletAddress: entry.walletAddress,
        orderId: entry.orderId,
        codeVerifier: entry.codeVerifier,
        redirectUri: entry.redirectUri,
        appRedirectUri: entry.appRedirectUri,
        appAutoRedirect: entry.appAutoRedirect,
        iat: Date.now(),
        exp: entry.expiresAt,
        nonce: randomBase64Url(16),
    };
    const payloadEncoded = encodeBase64UrlUtf8(JSON.stringify(payload));
    const signature = hmacSha256Base64Url(payloadEncoded, moneriumStateSecret);
    return `${payloadEncoded}.${signature}`;
};
const parseMoneriumStateToken = (state) => {
    try {
        const parts = state.split(".");
        if (parts.length !== 2) {
            return null;
        }
        const [payloadEncoded, signature] = parts;
        if (!payloadEncoded || !signature) {
            return null;
        }
        const expectedSignature = hmacSha256Base64Url(payloadEncoded, moneriumStateSecret);
        const signatureOk = constantTimeStringEqual(signature, expectedSignature);
        if (!signatureOk) {
            return null;
        }
        const raw = decodeBase64UrlUtf8(payloadEncoded);
        const parsed = JSON.parse(raw);
        if (parsed.v !== 1 ||
            typeof parsed.userId !== "string" ||
            typeof parsed.codeVerifier !== "string" ||
            typeof parsed.redirectUri !== "string" ||
            typeof parsed.exp !== "number") {
            return null;
        }
        const expiresAt = parsed.exp;
        const createdAt = typeof parsed.iat === "number" ? parsed.iat : Date.now();
        if (Date.now() > expiresAt) {
            return null;
        }
        return {
            userId: parsed.userId,
            email: typeof parsed.email === "string" ? parsed.email : undefined,
            walletAddress: typeof parsed.walletAddress === "string"
                ? parsed.walletAddress
                : undefined,
            orderId: typeof parsed.orderId === "string" ? parsed.orderId : undefined,
            state,
            codeVerifier: parsed.codeVerifier,
            redirectUri: parsed.redirectUri,
            appRedirectUri: typeof parsed.appRedirectUri === "string"
                ? parsed.appRedirectUri
                : undefined,
            appAutoRedirect: parsed.appAutoRedirect === true,
            createdAt,
            expiresAt,
        };
    }
    catch {
        return null;
    }
};
const clearExpiredMoneriumState = () => {
    const now = Date.now();
    for (const [state, entry] of moneriumPkceStore.entries()) {
        if (entry.expiresAt <= now) {
            moneriumPkceStore.delete(state);
        }
    }
};
const toSingleHeader = (value) => Array.isArray(value) ? value[0] : value;
const resolveMoneriumRedirectUri = (req) => {
    if (configuredRedirectUri) {
        return configuredRedirectUri;
    }
    if (configuredPublicServerUrl) {
        return `${configuredPublicServerUrl.replace(/\/$/, "")}/monerium/oauth/callback`;
    }
    const forwardedProto = toSingleHeader(req.headers?.["x-forwarded-proto"]);
    const forwardedHost = toSingleHeader(req.headers?.["x-forwarded-host"]);
    const host = toSingleHeader(req.headers?.host);
    const protocol = (forwardedProto || req.protocol || "https")
        .split(",")[0]
        .trim();
    const resolvedHost = (forwardedHost || host || "").split(",")[0].trim();
    if (resolvedHost) {
        return `${protocol}://${resolvedHost}/monerium/oauth/callback`;
    }
    return `http://localhost:${String(PORT)}/monerium/oauth/callback`;
};
const makeError = (code, message, details, status = 400) => ({ ok: false, error: { code, message, details }, status });
const summarizeMoneriumErrorData = (data) => {
    if (!data || typeof data !== "object") {
        return null;
    }
    const map = data;
    const first = (...keys) => {
        for (const key of keys) {
            const value = map[key];
            if (typeof value === "string" && value.trim().length > 0) {
                return value.trim();
            }
        }
        return null;
    };
    const direct = first("message", "error_description", "detail", "title");
    if (direct) {
        return direct;
    }
    const nestedError = map.error;
    if (nestedError && typeof nestedError === "object") {
        const nested = nestedError;
        for (const key of ["message", "error_description", "detail", "title"]) {
            const value = nested[key];
            if (typeof value === "string" && value.trim().length > 0) {
                return value.trim();
            }
        }
    }
    return null;
};
const extractMoneriumAddressRows = (data) => {
    if (Array.isArray(data)) {
        return data;
    }
    if (!data || typeof data !== "object") {
        return [];
    }
    const map = data;
    const candidates = [
        map.addresses,
        map.items,
        map.results,
        map.data,
        map.wallets,
    ];
    for (const candidate of candidates) {
        if (Array.isArray(candidate)) {
            return candidate;
        }
    }
    return [];
};
const maskTokenForLog = (value) => {
    if (!value || !value.trim())
        return "missing";
    if (value.length <= 12)
        return `len:${value.length}`;
    return `${value.slice(0, 6)}...${value.slice(-4)} (len:${value.length})`;
};
const normalizeTokenResponse = (payload) => {
    const expiresInSec = Number(payload.expires_in ?? 3600);
    return {
        accessToken: payload.access_token,
        refreshToken: payload.refresh_token,
        tokenType: payload.token_type || "Bearer",
        scope: payload.scope,
        createdAt: Date.now(),
        expiresAt: Date.now() + Math.max(60, expiresInSec) * 1000,
    };
};
const exchangeMoneriumCodeForToken = async (params) => {
    const body = new URLSearchParams({
        grant_type: "authorization_code",
        code: params.code,
        code_verifier: params.codeVerifier,
        redirect_uri: params.redirectUri,
        client_id: moneriumClientId,
        client_secret: moneriumClientSecret,
    });
    const response = await fetch(makeMoneriumUrl(moneriumTokenPath), {
        method: "POST",
        headers: {
            "Content-Type": "application/x-www-form-urlencoded",
            Accept: "application/json",
        },
        body: body.toString(),
    });
    const text = await response.text();
    const json = (() => {
        try {
            return JSON.parse(text);
        }
        catch {
            return { raw: text };
        }
    })();
    if (!response.ok) {
        throw makeError("MONERIUM_TOKEN_EXCHANGE_FAILED", "Failed to exchange Monerium auth code for token.", json, response.status);
    }
    return normalizeTokenResponse(json);
};
const refreshMoneriumToken = async (userId) => {
    const existing = moneriumTokenStore.get(userId);
    if (!existing?.refreshToken) {
        throw makeError("MONERIUM_REFRESH_TOKEN_MISSING", "No refresh token available for this user.", { userId }, 400);
    }
    const body = new URLSearchParams({
        grant_type: "refresh_token",
        refresh_token: existing.refreshToken,
        client_id: moneriumClientId,
        client_secret: moneriumClientSecret,
    });
    const response = await fetch(makeMoneriumUrl(moneriumTokenPath), {
        method: "POST",
        headers: {
            "Content-Type": "application/x-www-form-urlencoded",
            Accept: "application/json",
        },
        body: body.toString(),
    });
    const text = await response.text();
    const json = (() => {
        try {
            return JSON.parse(text);
        }
        catch {
            return { raw: text };
        }
    })();
    if (!response.ok) {
        throw makeError("MONERIUM_TOKEN_REFRESH_FAILED", "Failed to refresh Monerium access token.", json, response.status);
    }
    const next = normalizeTokenResponse(json);
    if (!next.refreshToken && existing.refreshToken) {
        next.refreshToken = existing.refreshToken;
    }
    moneriumTokenStore.set(userId, next);
    return next;
};
const getValidMoneriumToken = async (userId) => {
    const current = moneriumTokenStore.get(userId);
    if (!current) {
        throw makeError("MONERIUM_NOT_CONNECTED", "User is not connected to Monerium yet.", { userId }, 401);
    }
    const skewMs = 30_000;
    if (current.expiresAt - Date.now() <= skewMs) {
        return refreshMoneriumToken(userId);
    }
    return current;
};
const moneriumApiRequest = async (params) => {
    const usingOverride = Boolean(params.tokenOverride?.accessToken);
    console.log("➡️ Monerium API request", {
        userId: params.userId,
        method: params.method,
        path: params.path,
        usingOverride,
        overrideToken: maskTokenForLog(params.tokenOverride?.accessToken),
    });
    const token = params.tokenOverride?.accessToken
        ? {
            accessToken: params.tokenOverride.accessToken,
            refreshToken: params.tokenOverride.refreshToken,
            tokenType: params.tokenOverride.tokenType || "Bearer",
            scope: params.tokenOverride.scope,
            createdAt: Date.now(),
            expiresAt: params.tokenOverride.expiresAt || Date.now() + 55 * 60 * 1000,
        }
        : await getValidMoneriumToken(params.userId);
    const normalizedPath = params.path.split("?")[0].replace(/\/+$/, "");
    const normalizedOrdersPath = moneriumOrdersPath.replace(/\/+$/, "");
    const normalizedRedeemPath = moneriumRedeemPath.replace(/\/+$/, "");
    const requiresOrdersV2Accept = normalizedPath === normalizedOrdersPath ||
        normalizedPath.startsWith(`${normalizedOrdersPath}/`) ||
        normalizedPath === normalizedRedeemPath ||
        normalizedPath.startsWith(`${normalizedRedeemPath}/`);
    const acceptHeader = requiresOrdersV2Accept
        ? "application/vnd.monerium.api-v2+json"
        : "application/json";
    const url = makeMoneriumUrl(params.path, params.query);
    const controller = new AbortController();
    const requestTimeoutMs = params.timeoutMs ?? moneriumHttpTimeoutMs;
    const timeoutId = setTimeout(() => {
        controller.abort();
    }, requestTimeoutMs);
    let response;
    try {
        response = await fetch(url, {
            method: params.method,
            headers: {
                Authorization: `${token.tokenType || "Bearer"} ${token.accessToken}`,
                Accept: acceptHeader,
                "Content-Type": "application/json",
            },
            ...(params.body !== undefined
                ? { body: JSON.stringify(params.body) }
                : {}),
            signal: controller.signal,
        });
    }
    catch (error) {
        if (error?.name === "AbortError") {
            throw makeError("MONERIUM_UPSTREAM_TIMEOUT", `Monerium API timeout after ${requestTimeoutMs}ms for ${params.path}`, { path: params.path, timeoutMs: requestTimeoutMs }, 504);
        }
        throw error;
    }
    finally {
        clearTimeout(timeoutId);
    }
    const text = await response.text();
    const data = (() => {
        try {
            return text ? JSON.parse(text) : null;
        }
        catch {
            return { raw: text };
        }
    })();
    if (!response.ok) {
        const upstreamMessage = summarizeMoneriumErrorData(data);
        console.error("❌ Monerium API upstream error", {
            userId: params.userId,
            path: params.path,
            status: response.status,
            usingOverride,
            upstreamMessage,
            upstreamData: data,
        });
        throw makeError("MONERIUM_API_REQUEST_FAILED", upstreamMessage
            ? `Monerium API request failed: ${upstreamMessage}`
            : "Monerium API request failed.", { path: params.path, status: response.status, data }, response.status);
    }
    return data;
};
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
app.post("/cdp/get-account", async (req, res) => {
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
    }
    catch (error) {
        console.error("❌ Error getting account:", error);
        res.status(500).json({
            error: error instanceof Error ? error.message : "An unknown error occurred",
        });
    }
});
app.post("/cdp/create-or-get-account", async (req, res) => {
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
    }
    catch (error) {
        console.error("❌ Error creating account:", error);
        res.status(500).json({
            error: error instanceof Error ? error.message : "An unknown error occurred",
        });
    }
});
app.post("/cdp/request-testnet-faucet", async (req, res) => {
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
    }
    catch (error) {
        console.error("❌ Error creating account:", error);
        res.status(500).json({
            error: error instanceof Error ? error.message : "An unknown error occurred",
        });
    }
});
app.post("/cdp/get-balances", async (req, res) => {
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
            balances: balances.balances.map((balance) => {
                const rawAmount = BigInt(balance.amount.amount);
                const decimals = balance.amount.decimals;
                const humanReadable = Number(rawAmount) / Math.pow(10, decimals);
                console.log(`Token: ${balance.token.symbol}, Raw Amount: ${rawAmount}, Human Readable: ${humanReadable.toFixed(decimals)}`);
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
    }
    catch (error) {
        console.error("❌ Error getting balances:", error);
        res.status(500).json({
            error: error instanceof Error ? error.message : "An unknown error occurred",
        });
    }
});
app.post("/cdp/send-payment", async (req, res) => {
    try {
        const { fromAccountName, toAccountName, amountEurc } = req.body;
        console.log(`➡️ CDP account: ${fromAccountName} -> ${toAccountName} ${typeof amountEurc} ${amountEurc} EURC`);
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
        ];
        const result = await smartAccount.transfer({
            to: receiverSmartAccount.address,
            amount: parseUnits(amountEurc.toString(), 6),
            token: eurcContractAddress,
            network: "base-sepolia",
        });
        console.log("📥 Got payment response:", result);
        res.status(200).json(result);
    }
    catch (error) {
        console.error("❌ Error sending payment:", error);
        res.status(500).json({
            error: error instanceof Error ? error.message : "An unknown error occurred",
        });
    }
});
app.post("/cdp/create-onramp-session", async (req, res) => {
    try {
        const { accountName } = req.body;
        console.log(`➡️ Creating onramp session for CDP account: ${accountName}`);
        // ✅ Get client IP from request headers or body
        const clientIp = req.body.clientIp || // Use provided IP if testing
            req.headers["x-forwarded-for"]?.split(",")[0].trim() || // Proxy IP
            req.headers["x-real-ip"] || // Nginx
            req.ip || // Express default
            req.connection.remoteAddress; // Fallback
        console.log(`🌐 Client IP detected: ${clientIp}`);
        // ✅ Check if it's a private IP
        const isPrivateIp = /^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.|::1|fe80:)/.test(clientIp);
        if (isPrivateIp) {
            console.warn(`⚠️ Private IP detected (${clientIp}), will omit from request`);
        }
        const sender = await cdp.evm.getAccount({
            name: accountName,
        });
        const smartAccount = await cdp.evm.getOrCreateSmartAccount({
            owner: sender,
            name: accountName,
        });
        const token = await generateJwt({
            apiKeyId: process.env.CDP_API_KEY_ID,
            apiKeySecret: process.env.CDP_API_KEY_SECRET,
            requestMethod: "POST",
            requestHost: "api.cdp.coinbase.com",
            requestPath: "/platform/v2/onramp/sessions",
            expiresIn: 120, // optional (defaults to 120 seconds)
        });
        console.log("📥 Got onramp session token:", token, "   FOR account address: ", smartAccount.address);
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
        const response = await fetch("https://api.cdp.coinbase.com/platform/v2/onramp/sessions", options);
        console.log("📥 Onramp session response status:", response, response.status, response.statusText);
        const data = await response.json();
        res.status(200).json(data);
    }
    catch (error) {
        console.error("❌ Error creating onramp session:", error);
        res.status(500).json({
            error: error instanceof Error ? error.message : "An unknown error occurred",
        });
    }
});
app.post("/cdp/get-onramp-session-url", async (req, res) => {
    try {
        const { address } = req.body;
        console.log(`➡️ Creating onramp session for CDP account: ${address}`);
        // ✅ Get client IP from request headers or body
        const clientIp = req.body.clientIp || // Use provided IP if testing
            req.headers["x-forwarded-for"]?.split(",")[0].trim() || // Proxy IP
            req.headers["x-real-ip"] || // Nginx
            req.ip || // Express default
            req.connection.remoteAddress; // Fallback
        console.log(`🌐 Client IP detected: ${clientIp}`);
        // ✅ Check if it's a private IP
        const isPrivateIp = /^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.|::1|fe80:)/.test(clientIp);
        if (isPrivateIp) {
            console.warn(`⚠️ Private IP detected (${clientIp}), will omit from request`);
        }
        const token = await generateJwt({
            apiKeyId: process.env.CDP_API_KEY_ID,
            apiKeySecret: process.env.CDP_API_KEY_SECRET,
            requestMethod: "POST",
            requestHost: "api.cdp.coinbase.com",
            requestPath: "/platform/v2/onramp/sessions",
            expiresIn: 120, // optional (defaults to 120 seconds)
        });
        console.log("📥 Got onramp session token:", token, "   FOR account address: ", address);
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
        const response = await fetch("https://api.cdp.coinbase.com/platform/v2/onramp/sessions", options);
        console.log("📥 Onramp session response status:", response, response.status, response.statusText);
        const data = await response.json();
        res.status(200).json(data);
    }
    catch (error) {
        console.error("❌ Error creating onramp session:", error);
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
app.post("/cdp/exchange-code", async (req, res) => {
    try {
        const { token } = req.body ?? {};
        if (!token || typeof token !== "string" || token.length < 20) {
            return res.status(400).json({ error: "Missing token" });
        }
        const code = crypto.randomBytes(24).toString("hex");
        exchangeCodeStore.set(code, { token, expiresAt: Date.now() + 60_000 }); // 60 seconds
        return res.status(200).json({ code, expiresInSec: 60 });
    }
    catch (e) {
        return res.status(500).json({ error: e?.message ?? "Internal error" });
    }
});
app.post("/cdp/exchange-code/consume", async (req, res) => {
    try {
        const { code } = req.body ?? {};
        if (!code || typeof code !== "string") {
            return res.status(400).json({ error: "Missing code" });
        }
        const entry = exchangeCodeStore.get(code);
        if (!entry)
            return res.status(404).json({ error: "Invalid code" });
        if (Date.now() > entry.expiresAt) {
            exchangeCodeStore.delete(code);
            return res.status(410).json({ error: "Code expired" });
        }
        // one-time use
        exchangeCodeStore.delete(code);
        return res.status(200).json({ token: entry.token });
    }
    catch (e) {
        return res.status(500).json({ error: e?.message ?? "Internal error" });
    }
});
// ─── SIWE (Sign-In with Ethereum) ────────────────────────────────────────────
app.post("/monerium/siwe/start", async (req, res) => {
    try {
        if (!moneriumClientId) {
            return res
                .status(500)
                .json(makeError("MONERIUM_ENV_MISSING", "Missing MONERIUM_CLIENT_ID on server.", undefined, 500));
        }
        const { userId, walletAddress, appRedirectUri, orderId } = req.body ?? {};
        if (!userId || typeof userId !== "string") {
            return res
                .status(400)
                .json(makeError("MONERIUM_USER_ID_MISSING", "Missing userId."));
        }
        if (!walletAddress || typeof walletAddress !== "string") {
            return res
                .status(400)
                .json(makeError("MONERIUM_WALLET_MISSING", "Missing walletAddress."));
        }
        const codeVerifier = randomBase64Url(64);
        const codeChallenge = sha256Base64Url(codeVerifier);
        const oauthRedirectUri = resolveMoneriumRedirectUri(req);
        // EIP-4361 requires nonce to contain only alphanumeric characters (ALPHA / DIGIT).
        // Using hex encoding satisfies this: only [0-9a-f].
        const nonce = crypto.randomBytes(16).toString("hex");
        const issuedAt = new Date().toISOString();
        const expirationTime = new Date(Date.now() + 10 * 60 * 1000).toISOString();
        const domain = configuredPublicServerUrl
            ? new URL(configuredPublicServerUrl).host
            : req.get("host") || "slickbills.com";
        const siweMessage = [
            `${domain} wants you to sign in with your Ethereum account:`,
            walletAddress,
            "",
            moneriumSiweStatement,
            "",
            `URI: ${oauthRedirectUri}`,
            "Version: 1",
            `Chain ID: ${moneriumSiweChainId}`,
            `Nonce: ${nonce}`,
            `Issued At: ${issuedAt}`,
            `Expiration Time: ${expirationTime}`,
            "Resources:",
            "- https://monerium.com/siwe",
            `- ${moneriumSiwePrivacyUrl}`,
            `- ${moneriumSiweTermsUrl}`,
        ].join("\n");
        console.log("🔍 SIWE message being sent to Monerium:", {
            domain,
            statement: moneriumSiweStatement,
            chainId: moneriumSiweChainId,
            redirectUri: oauthRedirectUri,
        });
        const entryBase = {
            userId,
            email: undefined,
            walletAddress,
            orderId: typeof orderId === "string" ? orderId.trim() || undefined : undefined,
            codeVerifier,
            redirectUri: oauthRedirectUri,
            appRedirectUri: typeof appRedirectUri === "string" && appRedirectUri.trim().length > 0
                ? appRedirectUri.trim()
                : undefined,
            appAutoRedirect: false,
            createdAt: Date.now(),
            expiresAt: Date.now() + moneriumPkceTtlMs,
        };
        const state = createMoneriumStateToken({ ...entryBase, state: "" });
        const entry = { ...entryBase, state };
        moneriumPkceStore.set(state, entry);
        return res.status(200).json({
            ok: true,
            data: {
                message: siweMessage,
                state,
                codeChallenge,
                redirectUri: oauthRedirectUri,
            },
        });
    }
    catch (error) {
        console.error("❌ Monerium SIWE start failed:", error);
        return res
            .status(500)
            .json(makeError("MONERIUM_SIWE_START_FAILED", error instanceof Error ? error.message : "Unknown error", error, 500));
    }
});
app.post("/monerium/siwe/complete", async (req, res) => {
    try {
        if (!moneriumClientId) {
            return res
                .status(500)
                .json(makeError("MONERIUM_ENV_MISSING", "Missing MONERIUM_CLIENT_ID on server.", undefined, 500));
        }
        const { message, signature, state } = req.body ?? {};
        if (!message || typeof message !== "string") {
            return res
                .status(400)
                .json(makeError("MONERIUM_SIWE_MESSAGE_MISSING", "Missing message."));
        }
        if (!signature || typeof signature !== "string") {
            return res
                .status(400)
                .json(makeError("MONERIUM_SIWE_SIGNATURE_MISSING", "Missing signature."));
        }
        if (!state || typeof state !== "string") {
            return res
                .status(400)
                .json(makeError("MONERIUM_STATE_MISSING", "Missing state."));
        }
        const entry = moneriumPkceStore.get(state) || parseMoneriumStateToken(state);
        if (!entry || Date.now() > entry.expiresAt) {
            moneriumPkceStore.delete(state);
            return res
                .status(400)
                .json(makeError("MONERIUM_STATE_INVALID", "SIWE state is invalid or expired."));
        }
        // POST to Monerium /auth with authentication_method=siwe
        // Monerium will redirect to our callback with ?code=...
        const authBody = new URLSearchParams({
            client_id: moneriumClientId,
            code_challenge: sha256Base64Url(entry.codeVerifier),
            code_challenge_method: "S256",
            authentication_method: "siwe",
            message,
            signature,
            redirect_uri: entry.redirectUri,
            state,
        });
        const authResponse = await fetch(makeMoneriumUrl(moneriumAuthorizePath), {
            method: "POST",
            headers: {
                "Content-Type": "application/x-www-form-urlencoded",
                Accept: "application/json",
            },
            body: authBody.toString(),
            redirect: "manual",
        });
        // Monerium returns a 302 redirect to our callback URI with ?code=...
        // node-fetch with redirect:"manual" may expose the redirect as status 0
        // (opaque redirect) on some runtimes; treat that the same as 3xx.
        const isRedirect = authResponse.status === 0 ||
            (authResponse.status >= 300 && authResponse.status < 400);
        let code = null;
        let locationHeader = "";
        let redirectError = null;
        let redirectErrorDescription = null;
        if (isRedirect) {
            locationHeader =
                authResponse.headers.get("location") ??
                    authResponse.headers.get("Location") ??
                    "";
            console.log("🔄 Monerium SIWE /auth redirect", {
                status: authResponse.status,
                location: locationHeader || "(empty)",
            });
            if (locationHeader) {
                try {
                    const locationUrl = new URL(locationHeader.startsWith("http")
                        ? locationHeader
                        : `https://placeholder${locationHeader}`);
                    code = locationUrl.searchParams.get("code");
                    redirectError = locationUrl.searchParams.get("error");
                    redirectErrorDescription =
                        locationUrl.searchParams.get("error_description");
                }
                catch (urlErr) {
                    console.warn("⚠️ Could not parse Monerium redirect location URL", {
                        location: locationHeader,
                        err: String(urlErr),
                    });
                }
            }
        }
        else if (authResponse.status === 200) {
            // Some environments return JSON with the code instead of a redirect
            try {
                const json = await authResponse.json();
                if (json && typeof json === "object") {
                    const root = json;
                    const nested = root.data && typeof root.data === "object"
                        ? root.data
                        : null;
                    const rootCode = typeof root.code === "string" ? root.code : null;
                    const nestedCode = nested && typeof nested.code === "string" ? nested.code : null;
                    code = rootCode ?? nestedCode ?? null;
                }
            }
            catch {
                // ignore
            }
        }
        if (!code) {
            let onboardingRedirectUrl = null;
            if (!redirectError && locationHeader.startsWith("http")) {
                try {
                    const redirectHost = new URL(locationHeader).host;
                    if (/\.monerium\./i.test(redirectHost)) {
                        onboardingRedirectUrl = locationHeader;
                    }
                }
                catch {
                    onboardingRedirectUrl = null;
                }
            }
            if (onboardingRedirectUrl) {
                console.log("ℹ️ Monerium SIWE requires onboarding; redirecting user", {
                    status: authResponse.status,
                    location: onboardingRedirectUrl,
                });
                return res.status(200).json({
                    ok: true,
                    data: {
                        connected: false,
                        onboardingRequired: true,
                        redirectUrl: onboardingRedirectUrl,
                    },
                });
            }
            // Read the body only for non-redirect responses (redirect body is always empty)
            const body = isRedirect ? "" : await authResponse.text().catch(() => "");
            // Surface the OAuth error from the redirect URL when available
            const moneriumErrorMsg = redirectError
                ? `Monerium error: ${redirectError}${redirectErrorDescription ? ` — ${decodeURIComponent(redirectErrorDescription)}` : ""}`
                : null;
            console.error("❌ Monerium SIWE /auth did not return code", {
                status: authResponse.status,
                location: locationHeader || undefined,
                redirectError: redirectError || undefined,
                redirectErrorDescription: redirectErrorDescription || undefined,
                body: body || undefined,
            });
            return res.status(502).json(makeError("MONERIUM_SIWE_NO_CODE", moneriumErrorMsg ??
                "Monerium SIWE auth did not return an authorization code.", {
                status: authResponse.status,
                location: locationHeader || undefined,
                redirectError: redirectError || undefined,
            }, 502));
        }
        const token = await exchangeMoneriumCodeForToken({
            code,
            codeVerifier: entry.codeVerifier,
            redirectUri: entry.redirectUri,
        });
        console.log("✅ Monerium SIWE auth complete", {
            userId: entry.userId,
            hasAccessToken: Boolean(token.accessToken),
            expiresAt: token.expiresAt,
        });
        moneriumTokenStore.set(entry.userId, token);
        moneriumPkceStore.delete(state);
        const tokenOverride = {
            accessToken: token.accessToken,
            refreshToken: token.refreshToken,
            expiresAt: token.expiresAt,
            tokenType: token.tokenType,
            scope: token.scope,
        };
        const monitoredOrder = entry.orderId && entry.walletAddress
            ? await monitorMoneriumOrderByTransfer({
                userId: entry.userId,
                walletAddress: entry.walletAddress,
                orderId: entry.orderId,
                tokenOverride,
            })
            : null;
        const monitoredOrderState = monitoredOrder && typeof monitoredOrder.order.state === "string"
            ? monitoredOrder.order.state.trim().toLowerCase()
            : "";
        const monitoredTxHash = monitoredOrder && typeof monitoredOrder.txHash === "string"
            ? monitoredOrder.txHash.trim()
            : "";
        const paymentStatus = entry.orderId && entry.walletAddress
            ? monitoredTxHash && monitoredOrderState === "processed"
                ? "success"
                : "pending"
            : "success";
        // Build the deep-link redirect URL for the app
        let redirectUrl = null;
        if (entry.appRedirectUri) {
            try {
                const url = new URL(entry.appRedirectUri);
                url.searchParams.set("provider", "monerium");
                url.searchParams.set("status", paymentStatus);
                url.searchParams.set("userId", entry.userId);
                if (entry.orderId) {
                    url.searchParams.set("orderId", entry.orderId);
                }
                if (monitoredTxHash) {
                    url.searchParams.set("txHash", monitoredTxHash);
                }
                if (monitoredOrderState) {
                    url.searchParams.set("orderState", monitoredOrderState);
                }
                if (token.accessToken) {
                    url.searchParams.set("accessToken", token.accessToken);
                }
                if (token.refreshToken) {
                    url.searchParams.set("refreshToken", token.refreshToken);
                }
                if (typeof token.expiresAt === "number") {
                    url.searchParams.set("expiresAt", String(token.expiresAt));
                }
                redirectUrl = url.toString();
            }
            catch {
                // ignore malformed URI
            }
        }
        return res.status(200).json({
            ok: true,
            data: {
                userId: entry.userId,
                connected: true,
                status: paymentStatus,
                orderId: entry.orderId ?? null,
                txHash: monitoredTxHash || null,
                orderState: monitoredOrderState || null,
                expiresAt: token.expiresAt,
                accessToken: token.accessToken,
                refreshToken: token.refreshToken ?? null,
                redirectUrl,
            },
        });
    }
    catch (error) {
        console.error("❌ Monerium SIWE complete failed:", error);
        return res
            .status(500)
            .json(makeError("MONERIUM_SIWE_COMPLETE_FAILED", error instanceof Error ? error.message : "Unknown error", error, 500));
    }
});
// ─── Standard OAuth (browser redirect flow) ──────────────────────────────────
app.post("/monerium/oauth/start", async (req, res) => {
    try {
        clearExpiredMoneriumState();
        if (!moneriumClientId || !moneriumClientSecret) {
            return res
                .status(500)
                .json(makeError("MONERIUM_ENV_MISSING", "Missing MONERIUM_CLIENT_ID or MONERIUM_CLIENT_SECRET on server.", undefined, 500));
        }
        const { userId, email, appRedirectUri, appAutoRedirect, forceLogin } = req.body ?? {};
        if (!userId || typeof userId !== "string") {
            return res
                .status(400)
                .json(makeError("MONERIUM_USER_ID_MISSING", "Missing userId."));
        }
        const codeVerifier = randomBase64Url(64);
        const codeChallenge = sha256Base64Url(codeVerifier);
        const oauthRedirectUri = resolveMoneriumRedirectUri(req);
        const entryBase = {
            userId,
            email: typeof email === "string" ? email.trim() : undefined,
            codeVerifier,
            redirectUri: oauthRedirectUri,
            appRedirectUri: typeof appRedirectUri === "string" && appRedirectUri.trim().length > 0
                ? appRedirectUri.trim()
                : undefined,
            appAutoRedirect: appAutoRedirect === true,
            createdAt: Date.now(),
            expiresAt: Date.now() + moneriumPkceTtlMs,
        };
        const state = createMoneriumStateToken({
            ...entryBase,
            state: "",
        });
        const entry = {
            ...entryBase,
            state,
        };
        moneriumPkceStore.set(state, entry);
        const authQuery = {
            response_type: "code",
            client_id: moneriumClientId,
            redirect_uri: oauthRedirectUri,
            code_challenge: codeChallenge,
            code_challenge_method: "S256",
            scope: moneriumScope,
            state,
            skip_kyc: "true",
            prompt: "login",
        };
        if (forceLogin === true) {
            authQuery.prompt = "login select_account";
            authQuery.max_age = "0";
        }
        const authUrl = makeMoneriumUrl(moneriumAuthorizePath, authQuery);
        return res.status(200).json({
            ok: true,
            data: {
                authUrl,
                state,
                redirectUri: oauthRedirectUri,
                expiresInSec: Math.floor(moneriumPkceTtlMs / 1000),
            },
        });
    }
    catch (error) {
        console.error("❌ Monerium oauth start failed:", error);
        const failure = error && typeof error === "object" && "status" in error
            ? error
            : makeError("MONERIUM_OAUTH_START_FAILED", error instanceof Error ? error.message : "Unknown error", error, 500);
        return res.status(failure.status ?? 500).json(failure);
    }
});
app.get("/monerium/oauth/callback", async (req, res) => {
    try {
        clearExpiredMoneriumState();
        const code = typeof req.query.code === "string" ? req.query.code.trim() : undefined;
        const state = typeof req.query.state === "string" ? req.query.state.trim() : undefined;
        const oauthError = typeof req.query.error === "string" ? req.query.error.trim() : undefined;
        const oauthErrorDescription = typeof req.query.error_description === "string"
            ? req.query.error_description.trim()
            : undefined;
        if (!state) {
            return res
                .status(400)
                .json(makeError("MONERIUM_STATE_MISSING", "Missing OAuth state."));
        }
        const entry = moneriumPkceStore.get(state) || parseMoneriumStateToken(state);
        if (!entry || Date.now() > entry.expiresAt) {
            moneriumPkceStore.delete(state);
            return res
                .status(400)
                .json(makeError("MONERIUM_STATE_INVALID", "State invalid or expired."));
        }
        const finishByRedirect = (status, message, session) => {
            if (!entry.appRedirectUri)
                return false;
            try {
                const url = new URL(entry.appRedirectUri);
                url.searchParams.set("provider", "monerium");
                url.searchParams.set("status", status);
                url.searchParams.set("userId", entry.userId);
                if (session?.accessToken) {
                    url.searchParams.set("accessToken", session.accessToken);
                }
                if (session?.refreshToken) {
                    url.searchParams.set("refreshToken", session.refreshToken);
                }
                if (typeof session?.expiresAt === "number") {
                    url.searchParams.set("expiresAt", String(session.expiresAt));
                }
                if (message) {
                    url.searchParams.set("message", message);
                }
                const nextUrl = url.toString();
                const safeMessage = message ?? "Authentication finished.";
                const shouldAutoRedirect = moneriumAppAutoRedirectEnabled && entry.appAutoRedirect === true;
                const title = shouldAutoRedirect
                    ? "Returning to app"
                    : "Continue to app";
                const subtitle = shouldAutoRedirect
                    ? "You are being returned to the app..."
                    : "Tap the button below to return to the app.";
                res.status(200).setHeader("Content-Type", "text/html; charset=utf-8")
                    .send(`<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>${title}</title>
    ${shouldAutoRedirect ? `<meta http-equiv="refresh" content="0;url=${nextUrl}" />` : ""}
    <style>
      body {
        font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
        display: grid;
        place-items: center;
        min-height: 100vh;
        margin: 0;
        background: #0f172a;
        color: #e2e8f0;
      }
      a { color: #7dd3fc; }
    </style>
  </head>
  <body>
    <div>
      <p>${subtitle}</p>
      <p>${safeMessage}</p>
      <p><a href="${nextUrl}">Open the app</a></p>
    </div>
    ${shouldAutoRedirect ? `<script>window.location.replace(${JSON.stringify(nextUrl)});</script>` : ""}
  </body>
</html>`);
                return true;
            }
            catch {
                return false;
            }
        };
        if (oauthError) {
            moneriumPkceStore.delete(state);
            const message = oauthErrorDescription || oauthError;
            if (finishByRedirect("error", message)) {
                return;
            }
            return res
                .status(400)
                .json(makeError("MONERIUM_OAUTH_DENIED", "OAuth callback returned an error.", { oauthError, oauthErrorDescription }));
        }
        if (!code) {
            return res
                .status(400)
                .json(makeError("MONERIUM_CODE_MISSING", "Missing OAuth code."));
        }
        const token = await exchangeMoneriumCodeForToken({
            code,
            codeVerifier: entry.codeVerifier,
            redirectUri: entry.redirectUri,
        });
        console.log("✅ Monerium OAuth code exchanged", {
            userId: entry.userId,
            accessToken: maskTokenForLog(token.accessToken),
            hasRefreshToken: Boolean(token.refreshToken),
            expiresAt: token.expiresAt,
        });
        moneriumTokenStore.set(entry.userId, token);
        moneriumPkceStore.delete(state);
        if (finishByRedirect("success", undefined, token)) {
            return;
        }
        return res.status(200).json({
            ok: true,
            data: {
                userId: entry.userId,
                connected: true,
                expiresAt: token.expiresAt,
            },
        });
    }
    catch (error) {
        console.error("❌ Monerium oauth callback failed:", error);
        const failure = error && typeof error === "object" && "status" in error
            ? error
            : makeError("MONERIUM_OAUTH_CALLBACK_FAILED", error instanceof Error ? error.message : "Unknown error", error, 500);
        return res.status(failure.status ?? 500).json(failure);
    }
});
app.post("/monerium/oauth/refresh", async (req, res) => {
    try {
        const { userId, moneriumRefreshToken } = req.body ?? {};
        if (!userId || typeof userId !== "string") {
            return res
                .status(400)
                .json(makeError("MONERIUM_USER_ID_MISSING", "Missing userId."));
        }
        let token;
        if (typeof moneriumRefreshToken === "string" &&
            moneriumRefreshToken.trim().length > 0) {
            const body = new URLSearchParams({
                grant_type: "refresh_token",
                refresh_token: moneriumRefreshToken.trim(),
                client_id: moneriumClientId,
                client_secret: moneriumClientSecret,
            });
            const response = await fetch(makeMoneriumUrl(moneriumTokenPath), {
                method: "POST",
                headers: {
                    "Content-Type": "application/x-www-form-urlencoded",
                    Accept: "application/json",
                },
                body: body.toString(),
            });
            const text = await response.text();
            const json = (() => {
                try {
                    return JSON.parse(text);
                }
                catch {
                    return { raw: text };
                }
            })();
            if (!response.ok) {
                throw makeError("MONERIUM_TOKEN_REFRESH_FAILED", "Failed to refresh Monerium access token.", json, response.status);
            }
            token = normalizeTokenResponse(json);
            if (!token.refreshToken) {
                token.refreshToken = moneriumRefreshToken.trim();
            }
            moneriumTokenStore.set(userId, token);
        }
        else {
            token = await refreshMoneriumToken(userId);
        }
        return res.status(200).json({
            ok: true,
            data: {
                userId,
                accessToken: token.accessToken,
                refreshToken: token.refreshToken,
                tokenType: token.tokenType,
                expiresAt: token.expiresAt,
                scope: token.scope,
            },
        });
    }
    catch (error) {
        console.error("❌ Monerium refresh failed:", error);
        const failure = error && typeof error === "object" && "status" in error
            ? error
            : makeError("MONERIUM_OAUTH_REFRESH_FAILED", error instanceof Error ? error.message : "Unknown error", error, 500);
        return res.status(failure.status ?? 500).json(failure);
    }
});
app.get("/monerium/oauth/status", async (req, res) => {
    const userId = typeof req.query.userId === "string" ? req.query.userId.trim() : undefined;
    if (!userId) {
        return res
            .status(400)
            .json(makeError("MONERIUM_USER_ID_MISSING", "Missing userId."));
    }
    const token = moneriumTokenStore.get(userId);
    return res.status(200).json({
        ok: true,
        data: {
            userId,
            connected: Boolean(token),
            expiresAt: token?.expiresAt ?? null,
            scope: token?.scope ?? null,
        },
    });
});
app.post("/monerium/wallet/link", async (req, res) => {
    try {
        const { userId, address, chain, profile, message, signature } = req.body ?? {};
        const requestedChain = typeof chain === "string" && chain.trim().length > 0 ? chain.trim() : "";
        const resolvedChain = configuredMoneriumWalletChain || requestedChain;
        if (!userId || typeof userId !== "string") {
            return res
                .status(400)
                .json(makeError("MONERIUM_USER_ID_MISSING", "Missing userId."));
        }
        if (!address || typeof address !== "string") {
            return res
                .status(400)
                .json(makeError("MONERIUM_ADDRESS_MISSING", "Missing wallet address."));
        }
        if (!message || typeof message !== "string") {
            return res
                .status(400)
                .json(makeError("MONERIUM_MESSAGE_MISSING", "Missing signed message. Use: 'I hereby declare that I am the address owner.'"));
        }
        if (!signature || typeof signature !== "string") {
            return res
                .status(400)
                .json(makeError("MONERIUM_SIGNATURE_MISSING", "Missing wallet signature for Monerium address linking."));
        }
        if (!resolvedChain) {
            return res
                .status(400)
                .json(makeError("MONERIUM_CHAIN_MISSING", "Missing chain. Provide chain in request or set MONERIUM_WALLET_CHAIN."));
        }
        const payload = {
            ...(typeof profile === "string" && profile.trim()
                ? { profile: profile.trim() }
                : {}),
            address,
            chain: resolvedChain,
            message,
            signature,
        };
        const overrideAccessToken = typeof req.body?.moneriumAccessToken === "string"
            ? req.body.moneriumAccessToken
            : undefined;
        const overrideRefreshToken = typeof req.body?.moneriumRefreshToken === "string"
            ? req.body.moneriumRefreshToken
            : undefined;
        const overrideExpiresAt = typeof req.body?.moneriumExpiresAt === "number"
            ? req.body.moneriumExpiresAt
            : undefined;
        console.log("➡️ Monerium wallet link request", {
            userId,
            address,
            chain: payload.chain,
            hasProfile: Boolean(payload.profile),
            hasMessage: Boolean(message),
            hasSignature: Boolean(signature),
            hasOverrideToken: Boolean(overrideAccessToken),
            overrideAccessToken: maskTokenForLog(overrideAccessToken),
            hasOverrideRefreshToken: Boolean(overrideRefreshToken),
            overrideExpiresAt,
        });
        const data = await moneriumApiRequest({
            userId,
            method: "POST",
            path: moneriumWalletLinkPath,
            body: payload,
            tokenOverride: {
                accessToken: overrideAccessToken,
                refreshToken: overrideRefreshToken,
                expiresAt: overrideExpiresAt,
            },
        });
        let linkedConfirmed = false;
        let lastAddressesData = null;
        for (let attempt = 1; attempt <= moneriumLinkVerifyAttempts; attempt += 1) {
            const addresses = await moneriumApiRequest({
                userId,
                method: "GET",
                path: moneriumWalletLinkPath,
                tokenOverride: {
                    accessToken: overrideAccessToken,
                    refreshToken: overrideRefreshToken,
                    expiresAt: overrideExpiresAt,
                },
                timeoutMs: moneriumLinkVerifyFetchTimeoutMs,
            });
            lastAddressesData = addresses;
            linkedConfirmed = isMoneriumAddressLinked(addresses, address);
            if (linkedConfirmed) {
                break;
            }
            if (attempt < moneriumLinkVerifyAttempts) {
                await sleep(moneriumLinkVerifyIntervalMs);
            }
        }
        const matchedEntry = linkedConfirmed
            ? summarizeMoneriumAddressRow(findLinkedMoneriumAddressRow(lastAddressesData, address))
            : null;
        console.log("ℹ️ Monerium wallet link verification result", {
            userId,
            address,
            linkedConfirmed,
            verifyAttempts: moneriumLinkVerifyAttempts,
            matchedEntry: matchedEntry ?? undefined,
        });
        return res.status(200).json({
            ok: true,
            data,
            linkedConfirmed,
            linkedAddresses: lastAddressesData,
            matchedEntry,
        });
    }
    catch (error) {
        console.error("❌ Monerium wallet link failed:", error);
        const failure = error && typeof error === "object" && "status" in error
            ? error
            : makeError("MONERIUM_WALLET_LINK_FAILED", error instanceof Error ? error.message : "Unknown error", error, 500);
        return res.status(failure.status ?? 500).json(failure);
    }
});
app.get("/monerium/wallet/addresses", async (req, res) => {
    try {
        const userId = typeof req.query?.userId === "string" ? req.query.userId.trim() : "";
        const expectedAddress = typeof req.query?.address === "string" ? req.query.address.trim() : "";
        if (!userId) {
            return res
                .status(400)
                .json(makeError("MONERIUM_USER_ID_MISSING", "Missing userId."));
        }
        const overrideAccessToken = typeof req.query?.moneriumAccessToken === "string"
            ? req.query.moneriumAccessToken
            : undefined;
        const overrideRefreshToken = typeof req.query?.moneriumRefreshToken === "string"
            ? req.query.moneriumRefreshToken
            : undefined;
        const overrideExpiresAtRaw = req.query?.moneriumExpiresAt;
        const overrideExpiresAt = typeof overrideExpiresAtRaw === "string" &&
            overrideExpiresAtRaw.trim().length > 0
            ? Number(overrideExpiresAtRaw)
            : undefined;
        if (overrideExpiresAt !== undefined &&
            (!Number.isFinite(overrideExpiresAt) || overrideExpiresAt <= 0)) {
            return res
                .status(400)
                .json(makeError("MONERIUM_EXPIRES_AT_INVALID", "moneriumExpiresAt must be a valid positive number."));
        }
        console.log("➡️ Monerium wallet addresses request", {
            userId,
            hasOverrideToken: Boolean(overrideAccessToken),
            overrideAccessToken: maskTokenForLog(overrideAccessToken),
            hasOverrideRefreshToken: Boolean(overrideRefreshToken),
            overrideExpiresAt,
            expectedAddress: expectedAddress || undefined,
        });
        const data = await moneriumApiRequest({
            userId,
            method: "GET",
            path: moneriumWalletLinkPath,
            tokenOverride: {
                accessToken: overrideAccessToken,
                refreshToken: overrideRefreshToken,
                expiresAt: overrideExpiresAt,
            },
        });
        const addresses = extractMoneriumAddressRows(data);
        const topLevelKeys = data && typeof data === "object" && !Array.isArray(data)
            ? Object.keys(data).slice(0, 20)
            : undefined;
        const firstAddressRow = addresses.length > 0 ? addresses[0] : undefined;
        const linked = expectedAddress
            ? isMoneriumAddressLinked(data, expectedAddress)
            : undefined;
        console.log("✅ Monerium wallet addresses fetched", {
            userId,
            resultType: Array.isArray(data) ? "array" : typeof data,
            count: addresses.length,
            topLevelKeys,
            firstAddressRow,
            expectedAddress: expectedAddress || undefined,
            linked,
        });
        return res.status(200).json({
            ok: true,
            data,
            addresses,
            count: addresses.length,
            resultType: Array.isArray(data) ? "array" : typeof data,
            topLevelKeys,
            firstAddressRow,
            ...(expectedAddress ? { expectedAddress, linked: Boolean(linked) } : {}),
        });
    }
    catch (error) {
        console.error("❌ Monerium wallet addresses lookup failed:", error);
        const failure = error && typeof error === "object" && "status" in error
            ? error
            : makeError("MONERIUM_WALLET_ADDRESSES_FAILED", error instanceof Error ? error.message : "Unknown error", error, 500);
        return res.status(failure.status ?? 500).json(failure);
    }
});
app.get("/monerium/ibans", async (req, res) => {
    try {
        const userId = typeof req.query.userId === "string"
            ? req.query.userId.trim()
            : undefined;
        if (!userId) {
            return res
                .status(400)
                .json(makeError("MONERIUM_USER_ID_MISSING", "Missing userId."));
        }
        const overrideAccessToken = typeof req.query?.moneriumAccessToken === "string"
            ? req.query.moneriumAccessToken
            : undefined;
        const overrideRefreshToken = typeof req.query?.moneriumRefreshToken === "string"
            ? req.query.moneriumRefreshToken
            : undefined;
        const overrideExpiresAt = typeof req.query?.moneriumExpiresAt === "string"
            ? Number(req.query.moneriumExpiresAt)
            : undefined;
        console.log("➡️ Monerium IBAN fetch request", {
            userId,
            hasOverrideToken: Boolean(overrideAccessToken),
            overrideAccessToken: maskTokenForLog(overrideAccessToken),
            hasOverrideRefreshToken: Boolean(overrideRefreshToken),
            overrideExpiresAt,
        });
        const data = await moneriumApiRequest({
            userId,
            method: "GET",
            path: moneriumIbansPath,
            tokenOverride: {
                accessToken: overrideAccessToken,
                refreshToken: overrideRefreshToken,
                expiresAt: overrideExpiresAt,
            },
        });
        const ibanRows = extractMoneriumAddressRows({
            ibans: Array.isArray(data)
                ? data
                : data && typeof data === "object"
                    ? (() => {
                        const record = data;
                        const candidates = [
                            record.ibans,
                            record.items,
                            record.results,
                            record.data,
                        ];
                        for (const candidate of candidates) {
                            if (Array.isArray(candidate)) {
                                return candidate;
                            }
                        }
                        return [];
                    })()
                    : [],
        });
        const topLevelKeys = data && typeof data === "object" && !Array.isArray(data)
            ? Object.keys(data).slice(0, 20)
            : undefined;
        const firstIbanRow = ibanRows.length > 0 ? ibanRows[0] : undefined;
        const ibanCount = Array.isArray(data)
            ? data.length
            : data && typeof data === "object"
                ? (() => {
                    const record = data;
                    const candidates = [
                        record.ibans,
                        record.items,
                        record.results,
                        record.data,
                    ];
                    for (const candidate of candidates) {
                        if (Array.isArray(candidate)) {
                            return candidate.length;
                        }
                    }
                    return undefined;
                })()
                : undefined;
        console.log("✅ Monerium IBAN fetch success", {
            userId,
            resultType: Array.isArray(data) ? "array" : typeof data,
            count: ibanCount,
            topLevelKeys,
            firstIbanRow,
        });
        return res.status(200).json({
            ok: true,
            data,
            count: ibanCount,
            resultType: Array.isArray(data) ? "array" : typeof data,
            topLevelKeys,
            firstIbanRow,
        });
    }
    catch (error) {
        console.error("❌ Monerium iban fetch failed:", error);
        const failure = error && typeof error === "object" && "status" in error
            ? error
            : makeError("MONERIUM_IBAN_FETCH_FAILED", error instanceof Error ? error.message : "Unknown error", error, 500);
        return res.status(failure.status ?? 500).json(failure);
    }
});
app.post("/monerium/ibans/request", async (req, res) => {
    try {
        const { userId, address, chain } = req.body ?? {};
        const requestedChain = typeof chain === "string" && chain.trim().length > 0 ? chain.trim() : "";
        const resolvedChain = configuredMoneriumWalletChain || requestedChain;
        if (!userId || typeof userId !== "string") {
            return res
                .status(400)
                .json(makeError("MONERIUM_USER_ID_MISSING", "Missing userId."));
        }
        if (!address || typeof address !== "string") {
            return res
                .status(400)
                .json(makeError("MONERIUM_ADDRESS_MISSING", "Missing wallet address."));
        }
        if (!resolvedChain) {
            return res
                .status(400)
                .json(makeError("MONERIUM_CHAIN_MISSING", "Missing chain. Provide chain in request or set MONERIUM_WALLET_CHAIN."));
        }
        const overrideAccessToken = typeof req.body?.moneriumAccessToken === "string"
            ? req.body.moneriumAccessToken
            : undefined;
        const overrideRefreshToken = typeof req.body?.moneriumRefreshToken === "string"
            ? req.body.moneriumRefreshToken
            : undefined;
        const overrideExpiresAt = typeof req.body?.moneriumExpiresAt === "number"
            ? req.body.moneriumExpiresAt
            : undefined;
        console.log("➡️ Monerium IBAN request", {
            userId,
            address,
            chain: resolvedChain,
            hasOverrideToken: Boolean(overrideAccessToken),
            overrideAccessToken: maskTokenForLog(overrideAccessToken),
            hasOverrideRefreshToken: Boolean(overrideRefreshToken),
            overrideExpiresAt,
        });
        const data = await moneriumApiRequest({
            userId,
            method: "POST",
            path: moneriumIbansPath,
            body: {
                address,
                chain: resolvedChain,
            },
            tokenOverride: {
                accessToken: overrideAccessToken,
                refreshToken: overrideRefreshToken,
                expiresAt: overrideExpiresAt,
            },
        });
        return res.status(200).json({
            ok: true,
            accepted: true,
            data,
        });
    }
    catch (error) {
        if (error &&
            typeof error === "object" &&
            "status" in error &&
            Number(error.status) === 304) {
            const details = error?.error?.details;
            return res.status(200).json({
                ok: true,
                accepted: false,
                alreadyExists: true,
                data: details?.data ?? details ?? null,
            });
        }
        console.error("❌ Monerium IBAN request failed:", error);
        const failure = error && typeof error === "object" && "status" in error
            ? error
            : makeError("MONERIUM_IBAN_REQUEST_FAILED", error instanceof Error ? error.message : "Unknown error", error, 500);
        return res.status(failure.status ?? 500).json(failure);
    }
});
app.get("/monerium/balances", async (req, res) => {
    try {
        const userId = typeof req.query?.userId === "string" ? req.query.userId.trim() : "";
        const address = typeof req.query?.address === "string" ? req.query.address.trim() : "";
        const requestedChain = typeof req.query?.chain === "string" ? req.query.chain.trim() : "";
        const chain = requestedChain || configuredMoneriumWalletChain;
        if (!userId) {
            return res
                .status(400)
                .json(makeError("MONERIUM_USER_ID_MISSING", "Missing userId."));
        }
        if (!address) {
            return res
                .status(400)
                .json(makeError("MONERIUM_ADDRESS_MISSING", "Missing wallet address."));
        }
        if (!chain) {
            return res
                .status(400)
                .json(makeError("MONERIUM_CHAIN_MISSING", "Missing chain. Provide chain query or set MONERIUM_WALLET_CHAIN."));
        }
        const requestedCurrency = typeof req.query?.currency === "string"
            ? req.query.currency.trim().toLowerCase()
            : "";
        const overrideAccessToken = typeof req.query?.moneriumAccessToken === "string"
            ? req.query.moneriumAccessToken
            : undefined;
        const overrideRefreshToken = typeof req.query?.moneriumRefreshToken === "string"
            ? req.query.moneriumRefreshToken
            : undefined;
        const overrideExpiresAtRaw = req.query?.moneriumExpiresAt;
        const overrideExpiresAt = typeof overrideExpiresAtRaw === "string" &&
            overrideExpiresAtRaw.trim().length > 0
            ? Number(overrideExpiresAtRaw)
            : undefined;
        if (overrideExpiresAt !== undefined &&
            (!Number.isFinite(overrideExpiresAt) || overrideExpiresAt <= 0)) {
            return res
                .status(400)
                .json(makeError("MONERIUM_EXPIRES_AT_INVALID", "moneriumExpiresAt must be a valid positive number."));
        }
        const path = resolveMoneriumBalancesPath(chain, address);
        console.log("➡️ Monerium balances request", {
            userId,
            address,
            chain,
            currency: requestedCurrency || undefined,
            path,
            hasOverrideToken: Boolean(overrideAccessToken),
            overrideAccessToken: maskTokenForLog(overrideAccessToken),
            hasOverrideRefreshToken: Boolean(overrideRefreshToken),
            overrideExpiresAt,
        });
        const data = await moneriumApiRequest({
            userId,
            method: "GET",
            path,
            query: {
                ...(requestedCurrency ? { currency: requestedCurrency } : {}),
            },
            tokenOverride: {
                accessToken: overrideAccessToken,
                refreshToken: overrideRefreshToken,
                expiresAt: overrideExpiresAt,
            },
        });
        const balances = data && typeof data === "object" && !Array.isArray(data)
            ? data.balances
            : undefined;
        console.log("✅ Monerium balances fetched", {
            userId,
            address,
            chain,
            resultType: Array.isArray(data) ? "array" : typeof data,
            count: Array.isArray(balances) ? balances.length : undefined,
        });
        return res.status(200).json({
            ok: true,
            data,
            address,
            chain,
            count: Array.isArray(balances) ? balances.length : undefined,
        });
    }
    catch (error) {
        console.error("❌ Monerium balances fetch failed:", error);
        const failure = error && typeof error === "object" && "status" in error
            ? error
            : makeError("MONERIUM_BALANCES_FETCH_FAILED", error instanceof Error ? error.message : "Unknown error", error, 500);
        return res.status(failure.status ?? 500).json(failure);
    }
});
app.post("/monerium/orders/redeem", async (req, res) => {
    try {
        const { userId, amount, currency, destinationIban, recipientName, reference, walletAddress, } = req.body ?? {};
        if (!userId || typeof userId !== "string") {
            return res
                .status(400)
                .json(makeError("MONERIUM_USER_ID_MISSING", "Missing userId."));
        }
        if (!amount) {
            return res
                .status(400)
                .json(makeError("MONERIUM_AMOUNT_MISSING", "Missing amount."));
        }
        if (!destinationIban || typeof destinationIban !== "string") {
            return res
                .status(400)
                .json(makeError("MONERIUM_IBAN_MISSING", "Missing destinationIban."));
        }
        const orderPayload = {
            kind: "redeem",
            amount,
            currency: typeof currency === "string" && currency.trim() ? currency : "EUR",
            destination: {
                iban: destinationIban,
                name: typeof recipientName === "string" ? recipientName : undefined,
            },
            reference: typeof reference === "string" ? reference : undefined,
            walletAddress: typeof walletAddress === "string" ? walletAddress : undefined,
        };
        const data = await moneriumApiRequest({
            userId,
            method: "POST",
            path: moneriumRedeemPath,
            body: orderPayload,
        });
        return res.status(200).json({ ok: true, data });
    }
    catch (error) {
        console.error("❌ Monerium redeem failed:", error);
        const failure = error && typeof error === "object" && "status" in error
            ? error
            : makeError("MONERIUM_REDEEM_FAILED", error instanceof Error ? error.message : "Unknown error", error, 500);
        return res.status(failure.status ?? 500).json(failure);
    }
});
app.post("/monerium/orders/send", async (req, res) => {
    try {
        const { userId, order } = req.body ?? {};
        if (!userId || typeof userId !== "string") {
            return res
                .status(400)
                .json(makeError("MONERIUM_USER_ID_MISSING", "Missing userId."));
        }
        if (!order || typeof order !== "object" || Array.isArray(order)) {
            return res
                .status(400)
                .json(makeError("MONERIUM_ORDER_PAYLOAD_MISSING", "Missing order payload object."));
        }
        const orderPayload = { ...order };
        const kind = typeof orderPayload.kind === "string" ? orderPayload.kind.trim() : "";
        if (kind.toLowerCase() != "redeem") {
            return res
                .status(400)
                .json(makeError("MONERIUM_ORDER_KIND_INVALID", "Order kind must be 'redeem' for send-money flow."));
        }
        if (!orderPayload.address ||
            typeof orderPayload.address !== "string" ||
            !orderPayload.address.trim()) {
            return res
                .status(400)
                .json(makeError("MONERIUM_ORDER_ADDRESS_MISSING", "Order payload missing address."));
        }
        const bodyChain = typeof orderPayload.chain === "string" ? orderPayload.chain.trim() : "";
        const resolvedChain = bodyChain || configuredMoneriumWalletChain;
        if (!resolvedChain) {
            return res
                .status(400)
                .json(makeError("MONERIUM_CHAIN_MISSING", "Order payload missing chain. Provide order.chain or set MONERIUM_WALLET_CHAIN."));
        }
        orderPayload.chain = resolvedChain;
        if (!orderPayload.amount) {
            return res
                .status(400)
                .json(makeError("MONERIUM_ORDER_AMOUNT_MISSING", "Order payload missing amount."));
        }
        if (!orderPayload.currency ||
            typeof orderPayload.currency !== "string" ||
            !orderPayload.currency.trim()) {
            return res
                .status(400)
                .json(makeError("MONERIUM_ORDER_CURRENCY_MISSING", "Order payload missing currency."));
        }
        if (!orderPayload.counterpart ||
            typeof orderPayload.counterpart !== "object") {
            return res
                .status(400)
                .json(makeError("MONERIUM_ORDER_COUNTERPART_MISSING", "Order payload missing counterpart object."));
        }
        if (!orderPayload.message ||
            typeof orderPayload.message !== "string" ||
            !orderPayload.message.trim()) {
            return res
                .status(400)
                .json(makeError("MONERIUM_ORDER_MESSAGE_MISSING", "Order payload missing message."));
        }
        if (!orderPayload.signature ||
            typeof orderPayload.signature !== "string" ||
            !orderPayload.signature.trim()) {
            return res
                .status(400)
                .json(makeError("MONERIUM_ORDER_SIGNATURE_MISSING", "Order payload missing signature."));
        }
        const overrideAccessToken = typeof req.body?.moneriumAccessToken === "string"
            ? req.body.moneriumAccessToken
            : undefined;
        const overrideRefreshToken = typeof req.body?.moneriumRefreshToken === "string"
            ? req.body.moneriumRefreshToken
            : undefined;
        const overrideExpiresAt = typeof req.body?.moneriumExpiresAt === "number"
            ? req.body.moneriumExpiresAt
            : undefined;
        console.log("➡️ Monerium send-money order request", {
            userId,
            kind: orderPayload.kind,
            chain: orderPayload.chain,
            currency: orderPayload.currency,
            hasAddress: Boolean(orderPayload.address),
            hasCounterpart: Boolean(orderPayload.counterpart),
            hasMessage: Boolean(orderPayload.message),
            hasSignature: Boolean(orderPayload.signature),
            hasOverrideToken: Boolean(overrideAccessToken),
            overrideAccessToken: maskTokenForLog(overrideAccessToken),
            hasOverrideRefreshToken: Boolean(overrideRefreshToken),
            overrideExpiresAt,
        });
        const tokenOverride = {
            accessToken: overrideAccessToken,
            refreshToken: overrideRefreshToken,
            expiresAt: overrideExpiresAt,
        };
        const data = await moneriumApiRequest({
            userId,
            method: "POST",
            path: moneriumOrdersPath,
            body: orderPayload,
            tokenOverride,
        });
        const createdOrder = data && typeof data === "object"
            ? data
            : {};
        const createdOrderId = extractOrderId(createdOrder);
        const orderWalletAddress = typeof orderPayload.address === "string" ? orderPayload.address : "";
        const monitoredOrder = createdOrderId && orderWalletAddress
            ? await monitorMoneriumOrderByTransfer({
                userId,
                walletAddress: orderWalletAddress,
                orderId: createdOrderId,
                tokenOverride,
            })
            : null;
        const monitoredOrderState = monitoredOrder && typeof monitoredOrder.order.state === "string"
            ? monitoredOrder.order.state.trim().toLowerCase()
            : "";
        const monitoredTxHash = monitoredOrder && typeof monitoredOrder.txHash === "string"
            ? monitoredOrder.txHash.trim()
            : "";
        const paymentStatus = monitoredTxHash && monitoredOrderState === "processed"
            ? "success"
            : "pending";
        return res.status(200).json({
            ok: true,
            data,
            paymentStatus,
            orderId: createdOrderId || null,
            txHash: monitoredTxHash || null,
            orderState: monitoredOrderState || null,
        });
    }
    catch (error) {
        console.error("❌ Monerium send-money order failed:", error);
        const failure = error && typeof error === "object" && "status" in error
            ? error
            : makeError("MONERIUM_SEND_ORDER_FAILED", error instanceof Error ? error.message : "Unknown error", error, 500);
        return res.status(failure.status ?? 500).json(failure);
    }
});
app.get("/monerium/orders", async (req, res) => {
    try {
        const userId = typeof req.query?.userId === "string" ? req.query.userId.trim() : "";
        if (!userId) {
            return res
                .status(400)
                .json(makeError("MONERIUM_USER_ID_MISSING", "Missing userId."));
        }
        const txHash = typeof req.query?.txHash === "string" ? req.query.txHash.trim() : "";
        const state = typeof req.query?.state === "string" ? req.query.state.trim() : "";
        const kind = typeof req.query?.kind === "string" ? req.query.kind.trim() : "";
        const chain = typeof req.query?.chain === "string" ? req.query.chain.trim() : "";
        const address = typeof req.query?.address === "string" ? req.query.address.trim() : "";
        const profile = typeof req.query?.profile === "string" ? req.query.profile.trim() : "";
        const overrideAccessToken = typeof req.query?.moneriumAccessToken === "string"
            ? req.query.moneriumAccessToken
            : undefined;
        const overrideRefreshToken = typeof req.query?.moneriumRefreshToken === "string"
            ? req.query.moneriumRefreshToken
            : undefined;
        const overrideExpiresAtRaw = req.query?.moneriumExpiresAt;
        const overrideExpiresAt = typeof overrideExpiresAtRaw === "string" &&
            overrideExpiresAtRaw.trim().length > 0
            ? Number(overrideExpiresAtRaw)
            : undefined;
        if (overrideExpiresAt !== undefined &&
            (!Number.isFinite(overrideExpiresAt) || overrideExpiresAt <= 0)) {
            return res
                .status(400)
                .json(makeError("MONERIUM_EXPIRES_AT_INVALID", "moneriumExpiresAt must be a valid positive number."));
        }
        const query = {
            ...(txHash ? { txHash } : {}),
            ...(state ? { state } : {}),
            ...(kind ? { kind } : {}),
            ...(chain ? { chain } : {}),
            ...(address ? { address } : {}),
            ...(profile ? { profile } : {}),
        };
        console.log("➡️ Monerium orders list request", {
            userId,
            txHash: txHash || undefined,
            state: state || undefined,
            kind: kind || undefined,
            chain: chain || undefined,
            address: address || undefined,
            profile: profile || undefined,
            hasOverrideToken: Boolean(overrideAccessToken),
            overrideAccessToken: maskTokenForLog(overrideAccessToken),
            hasOverrideRefreshToken: Boolean(overrideRefreshToken),
            overrideExpiresAt,
        });
        const data = await moneriumApiRequest({
            userId,
            method: "GET",
            path: moneriumOrdersPath,
            query,
            tokenOverride: {
                accessToken: overrideAccessToken,
                refreshToken: overrideRefreshToken,
                expiresAt: overrideExpiresAt,
            },
        });
        const count = Array.isArray(data)
            ? data.length
            : data && typeof data === "object"
                ? (() => {
                    const map = data;
                    const candidates = [map.items, map.results, map.data, map.orders];
                    for (const candidate of candidates) {
                        if (Array.isArray(candidate)) {
                            return candidate.length;
                        }
                    }
                    return undefined;
                })()
                : undefined;
        return res.status(200).json({
            ok: true,
            data,
            count,
            // Helpful for txHash monitoring flow: consume first match directly.
            firstOrder: Array.isArray(data) && data.length > 0 ? data[0] : null,
        });
    }
    catch (error) {
        console.error("❌ Monerium orders list failed:", error);
        const failure = error && typeof error === "object" && "status" in error
            ? error
            : makeError("MONERIUM_ORDERS_LIST_FAILED", error instanceof Error ? error.message : "Unknown error", error, 500);
        return res.status(failure.status ?? 500).json(failure);
    }
});
app.get("/monerium/orders/:orderId", async (req, res) => {
    try {
        const userId = typeof req.query.userId === "string"
            ? req.query.userId.trim()
            : undefined;
        const orderId = typeof req.params.orderId === "string"
            ? req.params.orderId.trim()
            : undefined;
        if (!userId) {
            return res
                .status(400)
                .json(makeError("MONERIUM_USER_ID_MISSING", "Missing userId."));
        }
        if (!orderId) {
            return res
                .status(400)
                .json(makeError("MONERIUM_ORDER_ID_MISSING", "Missing orderId."));
        }
        const overrideAccessToken = typeof req.query?.moneriumAccessToken === "string"
            ? req.query.moneriumAccessToken
            : undefined;
        const overrideRefreshToken = typeof req.query?.moneriumRefreshToken === "string"
            ? req.query.moneriumRefreshToken
            : undefined;
        const overrideExpiresAtRaw = req.query?.moneriumExpiresAt;
        const overrideExpiresAt = typeof overrideExpiresAtRaw === "string" &&
            overrideExpiresAtRaw.trim().length > 0
            ? Number(overrideExpiresAtRaw)
            : undefined;
        if (overrideExpiresAt !== undefined &&
            (!Number.isFinite(overrideExpiresAt) || overrideExpiresAt <= 0)) {
            return res
                .status(400)
                .json(makeError("MONERIUM_EXPIRES_AT_INVALID", "moneriumExpiresAt must be a valid positive number."));
        }
        const tokenOverride = {
            accessToken: overrideAccessToken,
            refreshToken: overrideRefreshToken,
            expiresAt: overrideExpiresAt,
        };
        const readOrdersArray = (raw) => {
            if (Array.isArray(raw)) {
                return raw.filter((item) => Boolean(item) && typeof item === "object");
            }
            if (!raw || typeof raw !== "object") {
                return [];
            }
            const map = raw;
            const candidates = [map.items, map.results, map.data, map.orders];
            for (const candidate of candidates) {
                if (Array.isArray(candidate)) {
                    return candidate.filter((item) => Boolean(item) && typeof item === "object");
                }
            }
            return [];
        };
        const findOrderById = (raw, targetOrderId) => {
            for (const order of readOrdersArray(raw)) {
                const id = typeof order.id === "string"
                    ? order.id.trim()
                    : typeof order.orderId === "string"
                        ? order.orderId.trim()
                        : "";
                if (id && id === targetOrderId) {
                    return order;
                }
            }
            return null;
        };
        let data;
        try {
            data = await moneriumApiRequest({
                userId,
                method: "GET",
                path: `${moneriumOrdersPath.replace(/\/$/, "")}/${encodeURIComponent(orderId)}`,
                tokenOverride,
            });
        }
        catch (error) {
            const maybeFailure = error && typeof error === "object" && "status" in error
                ? error
                : null;
            const status = maybeFailure?.status;
            const message = String(maybeFailure?.error?.message || maybeFailure?.message || "");
            const isEndpointMissing = status === 404 && message.toLowerCase().includes("endpoint not found");
            if (!isEndpointMissing) {
                throw error;
            }
            console.warn("⚠️ Monerium /orders/:id unsupported, using list fallback", {
                userId,
                orderId,
            });
            const listById = await moneriumApiRequest({
                userId,
                method: "GET",
                path: moneriumOrdersPath,
                query: {
                    id: orderId,
                    orderId,
                },
                tokenOverride,
            });
            const matchedFromFiltered = findOrderById(listById, orderId);
            if (matchedFromFiltered) {
                return res.status(200).json({
                    ok: true,
                    data: matchedFromFiltered,
                    fallback: "orders_list_filtered",
                });
            }
            const listAll = await moneriumApiRequest({
                userId,
                method: "GET",
                path: moneriumOrdersPath,
                tokenOverride,
            });
            const matchedFromAll = findOrderById(listAll, orderId);
            if (matchedFromAll) {
                return res.status(200).json({
                    ok: true,
                    data: matchedFromAll,
                    fallback: "orders_list_scan",
                });
            }
            return res
                .status(404)
                .json(makeError("MONERIUM_ORDER_NOT_FOUND", "Order not found in Monerium orders list fallback.", { orderId }, 404));
        }
        return res.status(200).json({ ok: true, data });
    }
    catch (error) {
        console.error("❌ Monerium order fetch failed:", error);
        const failure = error && typeof error === "object" && "status" in error
            ? error
            : makeError("MONERIUM_ORDER_FETCH_FAILED", error instanceof Error ? error.message : "Unknown error", error, 500);
        return res.status(failure.status ?? 500).json(failure);
    }
});
app.listen(PORT, () => {
    console.log(`Proxy server running on port ${PORT}`);
});
export default app;
