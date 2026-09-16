import { authConnector, WALLET_CONNECTORS } from "@web3auth/modal";
import type { Web3AuthContextConfig } from "@web3auth/modal/react";
import { resolveWeb3AuthNetwork } from "./config";
import { web3AuthSocialLoginMethods } from "./web3authSocialLogin";

function walletAuthRedirectUrl(): string | undefined {
  if (typeof window === "undefined") return undefined;
  return `${window.location.origin}${window.location.pathname}`;
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
