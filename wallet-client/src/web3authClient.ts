import { CONNECTOR_EVENTS, WALLET_CONNECTORS, Web3Auth } from "@web3auth/modal";
import { resolveWeb3AuthNetwork } from "./config";
import {
  inspectWeb3AuthSession,
  isWeb3AuthConnected,
  waitForWalletAddress,
} from "./web3authProvider";
import { web3AuthSocialLoginMethods } from "./web3authSocialLogin";

export function createSlickBillsWeb3Auth(clientId: string): Web3Auth {
  return new Web3Auth({
    clientId,
    web3AuthNetwork: resolveWeb3AuthNetwork(),
    enableLogging: true,
    uiConfig: {
      uxMode: "redirect",
      appName: "SlickBills",
    },
    modalConfig: {
      hideWalletDiscovery: false,
      connectors: {
        [WALLET_CONNECTORS.AUTH]: {
          label: "Web3Auth",
          showOnModal: true,
          loginMethods: web3AuthSocialLoginMethods(),
        },
        [WALLET_CONNECTORS.METAMASK]: {
          label: "MetaMask",
          showOnModal: true,
        },
        [WALLET_CONNECTORS.WALLET_CONNECT_V2]: {
          label: "WalletConnect",
          showOnModal: true,
        },
      },
    },
  });
}

export async function discardSessionWithoutAddress(
  web3Auth: Web3Auth,
): Promise<void> {
  try {
    await web3Auth.logout({ cleanup: true });
  } catch {
    try {
      await web3Auth.clearCache();
    } catch {
      // Ignore cache-clear failures; the next login can still proceed.
    }
  }
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => {
    window.setTimeout(resolve, ms);
  });
}

export async function waitUntilSdkReady(
  web3Auth: Web3Auth,
  onLog?: (line: string) => void,
): Promise<void> {
  const log = (line: string) => onLog?.(line);
  for (let attempt = 0; attempt < 40; attempt += 1) {
    const status = web3Auth.status;
    if (status && status !== "not_ready") {
      log(`sdk status=${status} after ${attempt * 250}ms`);
      return;
    }
    await delay(250);
  }
  log(`sdk still ${web3Auth.status ?? "unknown"} after wait`);
}

const AUTH_RETURN_HASH_KEY = "sb_w3a_return_hash";

function decodeBase64Url(value: string): string {
  const padded = value.replace(/-/g, "+").replace(/_/g, "/");
  const pad =
    padded.length % 4 === 0 ? "" : "=".repeat(4 - (padded.length % 4));
  return window.atob(padded + pad);
}

function authParamKeys(source: string): string[] {
  try {
    return [...new URLSearchParams(source.replace(/^#/, "")).keys()];
  } catch {
    return [];
  }
}

function describeB64Params(raw: string | null): string {
  if (!raw) return "b64=no";
  try {
    const parsed = JSON.parse(decodeBase64Url(raw)) as Record<string, unknown>;
    const keys = Object.keys(parsed);
    const error =
      typeof parsed.error === "string" && parsed.error.trim()
        ? parsed.error.trim()
        : "none";
    return `b64=yes keys=${keys.join(",") || "none"} sessionId=${Boolean(parsed.sessionId)} error=${error}`;
  } catch (err) {
    return `b64=yes decode=${err instanceof Error ? err.message : String(err)} len=${raw.length}`;
  }
}

export function snapshotAuthReturnHash(): void {
  try {
    const hash = window.location.hash;
    if (hash && hash !== "#") {
      window.sessionStorage.setItem(AUTH_RETURN_HASH_KEY, hash);
    }
  } catch {
    // Private mode can block sessionStorage; live location.hash is still logged.
  }
}

export function logCurrentUrl(onLog: (line: string) => void) {
  try {
    const url = new URL(window.location.href);
    const keys = [...url.searchParams.keys()];
    onLog(
      `url origin=${url.origin} path=${url.pathname} search=${keys.join(",") || "none"} hash=${url.hash ? "yes" : "no"}`,
    );
  } catch (err) {
    onLog(`url parse error=${err instanceof Error ? err.message : String(err)}`);
  }
}

/** Log Web3Auth redirect payload keys only — never token/session values. */
export function logAuthReturn(onLog: (line: string) => void, label: string) {
  try {
    const liveHash = window.location.hash;
    const savedHash =
      window.sessionStorage.getItem(AUTH_RETURN_HASH_KEY)?.trim() || "";
    const hash = liveHash && liveHash !== "#" ? liveHash : savedHash;
    const params = new URLSearchParams(hash.replace(/^#/, ""));
    onLog(
      `${label} hashLen=${hash.replace(/^#/, "").length} keys=${authParamKeys(hash).join(",") || "none"} saved=${savedHash ? "yes" : "no"}`,
    );
    onLog(`${label} ${describeB64Params(params.get("b64Params"))}`);
    const error = params.get("error");
    if (error) onLog(`${label} oauthError=${error}`);
  } catch (err) {
    onLog(
      `${label} parse error=${err instanceof Error ? err.message : String(err)}`,
    );
  }
}

export function listenForSdkAuthErrors(
  web3Auth: Web3Auth,
  onLog: (line: string) => void,
): void {
  const logError = (kind: string, error: unknown) => {
    const message =
      error instanceof Error
        ? error.message
        : typeof error === "string"
          ? error
          : String(error);
    onLog(`${kind}: ${message}`);
  };

  web3Auth.on(CONNECTOR_EVENTS.REHYDRATION_ERROR, (error: unknown) => {
    logError("rehydrate error", error);
  });
  web3Auth.on(CONNECTOR_EVENTS.ERRORED, (error: unknown) => {
    logError("sdk error", error);
  });
  web3Auth.on(CONNECTOR_EVENTS.CONNECTED, () => {
    onLog("sdk event=connected");
  });
}

export async function waitForSocialWallet(
  web3Auth: Web3Auth | null,
  connectResult?: unknown,
  expectedAddress?: string | null,
): Promise<{ provider: unknown; address: string }> {
  return waitForWalletAddress(web3Auth, connectResult, expectedAddress);
}

/**
 * After Google/Facebook redirect, v11 hydrates `connection.ethereumProvider`.
 * Keep the social session and wait for that provider instead of opening MetaMask.
 */
export async function recoverConnectedWallet(
  web3Auth: Web3Auth,
  expectedAddress?: string | null,
  onLog?: (line: string) => void,
): Promise<{ provider: unknown; address: string } | null> {
  const log = (line: string) => onLog?.(line);
  if (!isWeb3AuthConnected(web3Auth)) {
    log("recover: not connected");
    return null;
  }

  log("recover: waiting for ethereumProvider");
  try {
    const ready = await waitForWalletAddress(
      web3Auth,
      web3Auth.connection,
      expectedAddress,
      20,
    );
    log(`recover: address ${ready.address}`);
    return ready;
  } catch (err) {
    log(
      `recover wait failed: ${err instanceof Error ? err.message : String(err)}`,
    );
  }

  try {
    log("recover: switchChain 0x89");
    await web3Auth.switchChain({ chainId: "0x89" });
    const afterSwitch = await waitForWalletAddress(
      web3Auth,
      web3Auth.connection,
      expectedAddress,
      12,
    );
    log(`recover after switch: address ${afterSwitch.address}`);
    return afterSwitch;
  } catch (err) {
    log(
      `recover switch failed: ${err instanceof Error ? err.message : String(err)}`,
    );
  }

  const snapshot = await inspectWeb3AuthSession(web3Auth);
  snapshot.forEach(log);
  return null;
}
