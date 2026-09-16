import type { Web3Auth } from "@web3auth/modal";
import {
  isWeb3AuthConnected,
  waitForWalletAddress,
} from "./web3authProvider";

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
  if (!isWeb3AuthConnected(web3Auth)) {
    return null;
  }

  try {
    return await waitForWalletAddress(
      web3Auth,
      web3Auth.connection,
      expectedAddress,
      20,
    );
  } catch {
    // Provider may need an Ethereum chain switch before accounts resolve.
  }

  try {
    await web3Auth.switchChain({ chainId: "0x1" });
    return await waitForWalletAddress(
      web3Auth,
      web3Auth.connection,
      expectedAddress,
      12,
    );
  } catch {
    return null;
  }
}
