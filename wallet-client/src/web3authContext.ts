import { authConnector, WALLET_CONNECTORS } from "@web3auth/modal";
import type { Web3AuthContextConfig } from "@web3auth/modal/react";
import { resolveWeb3AuthNetwork } from "./config";
import { web3AuthSocialLoginMethods } from "./web3authSocialLogin";

/** Google returns to the origin. Dashboard whitelist is origin, not /wallet/metamask-auth. */
function walletAuthRedirectUrl(): string | undefined {
  if (typeof window === "undefined") return undefined;
  return window.location.origin;
}

export function isWeb3AuthRedirectReturn(): boolean {
  if (typeof window === "undefined") return false;
  const blob = `${window.location.hash}\n${window.location.search}`;
  return /(?:sessionId|session_id|b64Params|loginParams|id_token)=/i.test(blob);
}

const clientId = (import.meta.env.VITE_WEB3AUTH_CLIENT_ID as string | undefined)?.trim() ?? "";

export const web3AuthContextConfig: Web3AuthContextConfig = {
  web3AuthOptions: {
    clientId,
    web3AuthNetwork: resolveWeb3AuthNetwork(),
    enableLogging: true,
    defaultChainId: "0x1",
    uiConfig: {
      uxMode: "redirect",
      appName: "SlickBills",
    },
    connectors: [
      authConnector({
        connectorSettings: {
          uxMode: "redirect",
          redirectUrl: walletAuthRedirectUrl(),
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
  },
};
