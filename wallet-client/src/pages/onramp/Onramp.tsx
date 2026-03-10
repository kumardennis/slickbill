import { useCurrentUser } from "@coinbase/cdp-hooks";
import { toast } from "react-toastify";
import { getParentOrigin } from "../../utils";

const SERVER_URL = "https://express-ten-xi.vercel.app";
// const LOCAL_SERVER_URL = "http://localhost:3000";

export const Onramp = () => {
  const { currentUser } = useCurrentUser();
  const smartAccountAddress = currentUser?.evmSmartAccounts?.[0];

  const handleOnramp = async () => {
    if (!smartAccountAddress) {
      toast.info("Wallet not connected yet");
      return;
    }

    try {
      const res = await fetch(`${SERVER_URL}/cdp/get-onramp-session-url`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ address: smartAccountAddress }),
      });

      const text = await res.json();

      if (!res.ok) {
        // surface server error body (often HTML) for debugging
        toast.error(`Failed to create onramp session (${res.status})`);
        console.error("onramp-token error:", res.status, text);
        return;
      }

      console.log("onramp-token response:", JSON.stringify(text));

      const sessionUrl = text?.session.onrampUrl;
      if (!sessionUrl) {
        toast.error(`Missing session URL`);
        console.error(
          "onramp-token missing session URL:",
          text.session.onrampUrl,
        );
        return;
      }

      const payload = { type: "SB_ONRAMP", onrampUrl: sessionUrl };

      try {
        window.getOnrampUrlOutOfWeb = () => sessionUrl;
        const targetOrigin = getParentOrigin();
        window.parent?.postMessage(payload, targetOrigin);
      } catch (e) {
        console.warn("postMessage failed:", e);
      }
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "An error occurred");
      console.error("onramp exception:", e);
    }
  };

  return <button onClick={handleOnramp}>Buy EURC</button>;
};
