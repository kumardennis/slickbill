import { CHAIN_NAMESPACES, WALLET_CONNECTORS, Web3Auth } from "@web3auth/modal";
import { resolveWeb3AuthNetwork } from "./config";
import {
  isWeb3AuthConnected,
  waitForWalletAddress,
} from "./web3authProvider";
import { web3AuthSocialLoginMethods } from "./web3authSocialLogin";

export function createSlickBillsWeb3Auth(clientId: string): Web3Auth {
  return new Web3Auth({
    clientId,
    web3AuthNetwork: resolveWeb3AuthNetwork(),
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
      web3Auth.clearCache();
    } catch {
      // Ignore cache-clear failures; the next login can still proceed.
    }
  }
}

export async function waitForSocialWallet(
  web3Auth: Web3Auth | null,
  connectResult?: unknown,
  expectedAddress?: string | null,
): Promise<{ provider: unknown; address: string }> {
  return waitForWalletAddress(web3Auth, connectResult, expectedAddress);
}

async function tryWait(
  web3Auth: Web3Auth,
  connectResult: unknown,
  expectedAddress?: string | null,
  attempts = 16,
): Promise<{ provider: unknown; address: string } | null> {
  try {
    return await waitForWalletAddress(
      web3Auth,
      connectResult,
      expectedAddress,
      attempts,
    );
  } catch {
    return null;
  }
}

/**
 * After Google/Facebook redirect on Mainnet, AUTH is connected but the EOA
 * is often not ready yet. Keep that social session and finish the embedded
 * wallet instead of sending the user back to pick MetaMask/Rabby.
 */
export async function recoverConnectedWallet(
  web3Auth: Web3Auth,
  expectedAddress?: string | null,
): Promise<{ provider: unknown; address: string } | null> {
  if (!isWeb3AuthConnected(web3Auth)) return null;

  const ready = await tryWait(web3Auth, undefined, expectedAddress, 16);
  if (ready) return ready;

  try {
    const authResult = await web3Auth.connectTo(WALLET_CONNECTORS.AUTH);
    const fromAuth = await tryWait(web3Auth, authResult, expectedAddress, 12);
    if (fromAuth) return fromAuth;
  } catch {
    // Social connector may already be mid-redirect; continue.
  }

  try {
    const embedded = await web3Auth.connectTo(WALLET_CONNECTORS.METAMASK, {
      chainNamespace: CHAIN_NAMESPACES.EIP155,
    });
    const fromEmbedded = await tryWait(
      web3Auth,
      embedded,
      expectedAddress,
      12,
    );
    if (fromEmbedded) return fromEmbedded;
  } catch {
    // Connect Kit cancelled or unavailable.
  }

  await discardSessionWithoutAddress(web3Auth);
  return null;
}
