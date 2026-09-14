import { WEB3AUTH_NETWORK } from "@web3auth/base";

const STAGING_EXPRESS_SERVER_URL = "https://express-ten-xi.vercel.app";

function stripSlash(url: string): string {
  return url.endsWith("/") ? url.slice(0, -1) : url;
}

const appEnvRaw = (import.meta.env.VITE_APP_ENV ?? "").toLowerCase();

export const appEnv =
  appEnvRaw === "prod" || appEnvRaw === "production" ? "production" : "dev";

export const isDev = appEnv === "dev";

function resolveExpressServerUrl(): string {
  const fromEnv = import.meta.env.VITE_EXPRESS_SERVER_URL?.trim();
  if (fromEnv) return stripSlash(fromEnv);
  if (isDev) return STAGING_EXPRESS_SERVER_URL;
  throw new Error(
    "VITE_EXPRESS_SERVER_URL is required for production wallet-client builds",
  );
}

export const expressServerUrl = resolveExpressServerUrl();

/** Staging defaults to Sapphire Devnet. Production uses Sapphire Mainnet. */
export function resolveWeb3AuthNetwork() {
  const raw = (import.meta.env.VITE_WEB3AUTH_NETWORK ?? "")
    .trim()
    .toLowerCase();
  if (raw === "sapphire_mainnet" || raw === "mainnet") {
    return WEB3AUTH_NETWORK.SAPPHIRE_MAINNET;
  }
  if (raw === "sapphire_testnet" || raw === "testnet") {
    return WEB3AUTH_NETWORK.TESTNET;
  }
  if (raw === "sapphire_devnet" || raw === "devnet") {
    return WEB3AUTH_NETWORK.SAPPHIRE_DEVNET;
  }
  return appEnv === "production"
    ? WEB3AUTH_NETWORK.SAPPHIRE_MAINNET
    : WEB3AUTH_NETWORK.SAPPHIRE_DEVNET;
}
