import { WALLET_CONNECTORS, Web3Auth } from "@web3auth/modal";
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
