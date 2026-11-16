import {
  authConnector,
  CHAIN_NAMESPACES,
  WALLET_CONNECTORS,
} from "@web3auth/modal";
import type { Web3AuthContextConfig } from "@web3auth/modal/react";
import { appEnv, isDev, resolveWeb3AuthNetwork } from "./config";
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

const clientId =
  (import.meta.env.VITE_WEB3AUTH_CLIENT_ID as string | undefined)?.trim() ?? "";

/** Staging Monerium/Alchemy sandbox → Ethereum Sepolia. Prod → Ethereum mainnet. */
export const defaultWalletChainId = isDev ? "0xaa36a7" : "0x1";

const sepoliaChain = {
  chainNamespace: CHAIN_NAMESPACES.EIP155,
  chainId: "0xaa36a7",
  rpcTarget: "https://rpc.sepolia.org",
  displayName: "Ethereum Sepolia",
  blockExplorerUrl: "https://sepolia.etherscan.io",
  ticker: "ETH",
  tickerName: "Ethereum",
  decimals: 18,
  logo: "https://cryptologos.cc/logos/ethereum-eth-logo.png",
};

const ethereumMainnetChain = {
  chainNamespace: CHAIN_NAMESPACES.EIP155,
  chainId: "0x1",
  rpcTarget: "https://rpc.ankr.com/eth",
  displayName: "Ethereum Mainnet",
  blockExplorerUrl: "https://etherscan.io",
  ticker: "ETH",
  tickerName: "Ethereum",
  decimals: 18,
  logo: "https://cryptologos.cc/logos/ethereum-eth-logo.png",
};

const chains = isDev ? [sepoliaChain] : [ethereumMainnetChain];

/** Mainnet AUTH Google/Facebook 403s on Growth. Staging Devnet social stays on the modal. */
const showSocialOnModal = appEnv !== "production";

export const web3AuthContextConfig: Web3AuthContextConfig = {
  web3AuthOptions: {
    clientId,
    web3AuthNetwork: resolveWeb3AuthNetwork(),
    chains,
    defaultChainId: defaultWalletChainId,
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
          showOnModal: showSocialOnModal,
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
