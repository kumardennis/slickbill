import { WALLET_CONNECTORS, Web3Auth } from "@web3auth/modal";
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

export async function recoverConnectedWallet(
  web3Auth: Web3Auth,
  expectedAddress?: string | null,
): Promise<{ provider: unknown; address: string } | null> {
  if (!isWeb3AuthConnected(web3Auth)) return null;
  try {
    return await waitForWalletAddress(
      web3Auth,
      undefined,
      expectedAddress,
      8,
    );
  } catch {
    await discardSessionWithoutAddress(web3Auth);
    return null;
  }
}
