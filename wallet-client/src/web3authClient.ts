import {
  authConnector,
  CONNECTOR_EVENTS,
  isAuthConnector,
  WALLET_CONNECTORS,
  Web3Auth,
} from "@web3auth/modal";
import { resolveWeb3AuthNetwork } from "./config";
import {
  inspectWeb3AuthSession,
  isWeb3AuthConnected,
  waitForWalletAddress,
} from "./web3authProvider";
import { web3AuthSocialLoginMethods } from "./web3authSocialLogin";

function walletAuthRedirectUrl(): string {
  if (typeof window === "undefined") return "";
  return `${window.location.origin}${window.location.pathname}`;
}

export function createSlickBillsWeb3Auth(clientId: string): Web3Auth {
  const redirectUrl = walletAuthRedirectUrl();
  return new Web3Auth({
    clientId,
    web3AuthNetwork: resolveWeb3AuthNetwork(),
    enableLogging: true,
    uiConfig: {
      uxMode: "redirect",
      appName: "SlickBills",
    },
    // Listed first so the SDK's default AUTH connector (popup) is dropped as a duplicate.
    connectors: [
      authConnector({
        connectorSettings: {
          uxMode: "redirect",
          redirectUrl,
        },
      }),
    ],
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
    return `b64=yes keys=${keys.join(",") || "none"} sessionId=${Boolean(parsed.sessionId)} loginParams=${typeof parsed.loginParams} error=${error}`;
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

function readAuthReturnPayload(): Record<string, unknown> | null {
  try {
    const liveHash = window.location.hash;
    const savedHash =
      window.sessionStorage.getItem(AUTH_RETURN_HASH_KEY)?.trim() || "";
    const hash = liveHash && liveHash !== "#" ? liveHash : savedHash;
    const b64 = new URLSearchParams(hash.replace(/^#/, "")).get("b64Params");
    if (!b64) return null;
    const parsed = JSON.parse(decodeBase64Url(b64)) as unknown;
    if (!parsed || typeof parsed !== "object") return null;
    return parsed as Record<string, unknown>;
  } catch {
    return null;
  }
}

function parseLoginParams(raw: unknown): unknown {
  if (typeof raw !== "string") return raw;
  try {
    return JSON.parse(raw);
  } catch {
    return raw;
  }
}

/**
 * Google currently returns iframe/popup params (`nonce` + `loginParams`), not
 * `sessionId`. v11 Auth.init JSON.parse()s loginParams and aborts if it is
 * already an object, and Safari View often cannot finish the hidden iframe.
 * Complete that pending login, then connect AUTH.
 */
export async function completePendingSocialReturn(
  web3Auth: Web3Auth,
  onLog?: (line: string) => void,
): Promise<void> {
  const log = (line: string) => onLog?.(line);
  if (isWeb3AuthConnected(web3Auth)) {
    log("complete pending: already connected");
    return;
  }

  const connector = web3Auth.getConnector(WALLET_CONNECTORS.AUTH);
  if (!isAuthConnector(connector) || !connector.authInstance) {
    log("complete pending: no AUTH connector");
    return;
  }

  const auth = connector.authInstance;
  const authInternal = auth as unknown as {
    authProviderPromise?: Promise<unknown>;
  };
  log(
    `auth uxMode=${auth.options.uxMode ?? "none"} sessionId=${Boolean(auth.sessionId)}`,
  );
  if (auth.sessionId) {
    log("complete pending: session already on authInstance");
    return;
  }

  const payload = readAuthReturnPayload();
  const nonce = typeof payload?.nonce === "string" ? payload.nonce : "";
  if (!nonce || payload?.loginParams == null) {
    log("complete pending: no nonce/loginParams");
    return;
  }

  const loginParams = parseLoginParams(payload.loginParams);
  log("complete pending: posting nonce login to AUTH");
  try {
    if (authInternal.authProviderPromise) await authInternal.authProviderPromise;
    await auth.postLoginInitiatedMessage(
      loginParams as Parameters<typeof auth.postLoginInitiatedMessage>[0],
      nonce,
    );
    log(`complete pending: sessionId=${Boolean(auth.sessionId)}`);
  } catch (err) {
    log(
      `complete pending post failed: ${err instanceof Error ? err.message : String(err)}`,
    );
    return;
  }

  if (!auth.sessionId) return;

  try {
    const chainId = web3Auth.currentChainId || "0x89";
    log(`complete pending: AUTH connect chain=${chainId}`);
    await connector.connect({ chainId });
    log(`complete pending: connected=${String(web3Auth.connected)}`);
  } catch (err) {
    log(
      `complete pending connect failed: ${err instanceof Error ? err.message : String(err)}`,
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
