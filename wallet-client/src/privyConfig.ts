import type { PrivyClientConfig } from "@privy-io/react-auth";

export const privyAppId =
  (import.meta.env.VITE_PRIVY_APP_ID as string | undefined)?.trim() ?? "";

/** Google only. Privy has no native Facebook — custom OAuth later. */
export const privyConfig: PrivyClientConfig = {
  loginMethods: ["google"],
  appearance: {
    walletChainType: "ethereum-only",
    theme: "light",
    accentColor: "#0B2545",
  },
  embeddedWallets: {
    ethereum: {
      createOnLogin: "users-without-wallets",
    },
  },
};
