import { useEvmAddress } from "@coinbase/cdp-hooks";
import { createPublicClient, http, formatUnits } from "viem";
import { base } from "viem/chains";
import { useState, useEffect, useCallback } from "react";
import { getParentOrigin } from "../../utils";

const EURC_CONTRACT = "0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42";

export const Balance = () => {
  const { evmAddress } = useEvmAddress();
  const [balance, setBalance] = useState<string | null>(null);

  const getBalanceOutOfWeb = useCallback(() => balance, [balance]);

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);

    // Expose function for Flutter polling (WebView)
    window.getBalanceOutOfWeb = getBalanceOutOfWeb;

    if (!evmAddress) return;

    const client = createPublicClient({ chain: base, transport: http() });

    client
      .readContract({
        address: EURC_CONTRACT,
        abi: [
          {
            name: "balanceOf",
            type: "function",
            inputs: [{ name: "account", type: "address" }],
            outputs: [{ name: "", type: "uint256" }],
            stateMutability: "view",
          },
        ],
        functionName: "balanceOf",
        args: [evmAddress],
      })
      .then((bal) => {
        const formatted = formatUnits(bal as bigint, 6);
        setBalance(formatted);

        if (params.get("sb") === "1") {
          const payload = {
            type: "SB_BALANCE",
            address: evmAddress,
            balance: formatted,
          };

          // ✅ Don’t let postMessage crash the app on mobile
          try {
            const targetOrigin = getParentOrigin();
            window.parent?.postMessage(payload, targetOrigin);
          } catch (e) {
            console.warn("postMessage failed:", e);
          }
        }
      })
      .catch((e) => {
        console.error("balance readContract failed:", e);
      });
  }, [evmAddress, getBalanceOutOfWeb]);

  return <p>Balance: {balance} EURC</p>;
};
