import type { Web3Auth } from "@web3auth/modal";
import {
  inspectWeb3AuthSession,
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
