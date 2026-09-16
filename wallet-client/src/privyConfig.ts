import type { PrivyClientConfig } from "@privy-io/react-auth";

export const privyAppId =
  (import.meta.env.VITE_PRIVY_APP_ID as string | undefined)?.trim() ?? "";

/** Google + external wallets. Privy has no native Facebook — custom OAuth later. */
export const privyConfig: PrivyClientConfig = {
  loginMethods: ["google", "wallet"],
  appearance: {
    walletChainType: "ethereum-only",
    theme: "light",
    accentColor: "#0B2545",
    showWalletLoginFirst: false,
    landingHeader: "Connect wallet",
    walletList: [
      "detected_ethereum_wallets",
      "metamask",
      "rainbow",
      "coinbase_wallet",
      "wallet_connect",
    ],
  },
  embeddedWallets: {
    ethereum: {
      createOnLogin: "users-without-wallets",
    },
  },
};
