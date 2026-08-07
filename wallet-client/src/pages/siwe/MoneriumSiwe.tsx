import { WEB3AUTH_NETWORK } from "@web3auth/base";
import { Web3Auth } from "@web3auth/modal";
import { useCallback, useEffect, useRef, useState } from "react";

const EXCHANGE_SERVER_URL = "https://express-ten-xi.vercel.app";
const SIWE_PARAMS_SESSION_KEY = "monerium_siwe_params_v1";
const SIWE_PARAMS_LOCAL_KEY = "monerium_siwe_params_v1_local";

type Step = "idle" | "init" | "signing" | "completing" | "done" | "error";

type CompleteData = {
  redirectUrl?: string;
  status?: "success" | "pending" | string;
};

export function MoneriumSiwe() {
  const [step, setStep] = useState<Step>("idle");
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [statusText, setStatusText] = useState("Connecting wallet…");

  const web3AuthRef = useRef<Web3Auth | null>(null);
  const startedRef = useRef(false);

  // Read all params from URL once
  const params = new URLSearchParams(window.location.search);
  const rawUserId = params.get("userId")?.trim() ?? "";
  const rawWalletAddress = params.get("address")?.trim() ?? "";
  const rawAppRedirectUri = params.get("app_redirect_uri")?.trim() ?? "";
  const rawOrderId = params.get("orderId")?.trim() ?? "";

  const readPersistedParams = (storage: Storage | undefined | null) => {
    try {
      const raw = storage?.getItem(SIWE_PARAMS_SESSION_KEY);
      if (!raw) return null;
      const parsed = JSON.parse(raw) as {
        userId?: string;
        walletAddress?: string;
        appRedirectUri?: string;
        orderId?: string;
      };
      return parsed;
    } catch {
      return null;
    }
  };

  const persistedParams =
    readPersistedParams(window.sessionStorage) ??
    (() => {
      try {
        const raw = window.localStorage.getItem(SIWE_PARAMS_LOCAL_KEY);
        if (!raw) return null;
        const parsed = JSON.parse(raw) as {
          userId?: string;
          walletAddress?: string;
          appRedirectUri?: string;
          orderId?: string;
        };
        return parsed;
      } catch {
        return null;
      }
    })();

  const userId = rawUserId || persistedParams?.userId?.trim() || "";
  const walletAddress =
    rawWalletAddress || persistedParams?.walletAddress?.trim() || "";
  const appRedirectUri =
    rawAppRedirectUri || persistedParams?.appRedirectUri?.trim() || "";
  const orderId = rawOrderId || persistedParams?.orderId?.trim() || "";

  const fail = useCallback(
    (msg: string) => {
      setErrorMsg(msg);
      setStep("error");

      if (appRedirectUri) {
        try {
          const url = new URL(appRedirectUri);
          url.searchParams.set("provider", "monerium");
          url.searchParams.set("status", "error");
          url.searchParams.set("message", msg);
          setTimeout(() => {
            window.location.assign(url.toString());
          }, 1500);
        } catch {
          // ignore
        }
      }
    },
    [appRedirectUri],
  );

  const run = useCallback(async () => {
    try {
      const paramsToPersist = {
        userId: rawUserId || persistedParams?.userId?.trim() || "",
        walletAddress:
          rawWalletAddress || persistedParams?.walletAddress?.trim() || "",
        appRedirectUri:
          rawAppRedirectUri || persistedParams?.appRedirectUri?.trim() || "",
        orderId: rawOrderId || persistedParams?.orderId?.trim() || "",
      };

      try {
        sessionStorage.setItem(
          SIWE_PARAMS_SESSION_KEY,
          JSON.stringify(paramsToPersist),
        );
        localStorage.setItem(
          SIWE_PARAMS_LOCAL_KEY,
          JSON.stringify(paramsToPersist),
        );
      } catch {
        // ignore storage errors
      }

      if (!userId || !walletAddress) {
        throw new Error("Missing userId or walletAddress in URL params.");
      }

      try {
        sessionStorage.setItem(
          SIWE_PARAMS_SESSION_KEY,
          JSON.stringify({ userId, walletAddress, appRedirectUri, orderId }),
        );
      } catch {
        // ignore storage errors
      }

      // ── 1. Init web3auth ──────────────────────────────────────────────
      setStep("init");
      setStatusText("Initialising wallet…");

      const clientId = import.meta.env.VITE_WEB3AUTH_CLIENT_ID as
        | string
        | undefined;
      const rawNetwork = (
        import.meta.env.VITE_WEB3AUTH_NETWORK as string | undefined
      )
        ?.trim()
        .toLowerCase();

      const resolvedNetwork =
        rawNetwork === "sapphire_devnet" || rawNetwork === "devnet"
          ? WEB3AUTH_NETWORK.SAPPHIRE_DEVNET
          : rawNetwork === "sapphire_testnet" || rawNetwork === "testnet"
            ? WEB3AUTH_NETWORK.TESTNET
            : WEB3AUTH_NETWORK.SAPPHIRE_DEVNET;

      if (!clientId) throw new Error("Missing VITE_WEB3AUTH_CLIENT_ID");

      const web3Auth = new Web3Auth({
        clientId,
        web3AuthNetwork: resolvedNetwork,
        uiConfig: { uxMode: "redirect" },
        modalConfig: {
          hideWalletDiscovery: false,
          connectors: {
            auth: {
              label: "Web3Auth",
              showOnModal: true,
              loginMethods: {
                google: { name: "Google", showOnModal: true },
              },
            },
            metamask: { label: "MetaMask", showOnModal: true },
            "wallet-connect-v2": { label: "WalletConnect", showOnModal: true },
          },
        },
      });

      await web3Auth.init();
      web3AuthRef.current = web3Auth;

      // ── 2. Get SIWE message from backend ─────────────────────────────
      setStatusText("Preparing sign-in message…");
      const startRes = await fetch(
        `${EXCHANGE_SERVER_URL}/monerium/siwe/start`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            userId,
            walletAddress,
            appRedirectUri,
            orderId,
          }),
        },
      );

      if (!startRes.ok) {
        const err = await startRes.json().catch(() => null);
        throw new Error(err?.error?.message ?? "Failed to start SIWE flow.");
      }

      const startData = (await startRes.json()).data as {
        message: string;
        state: string;
      };

      // ── 3. Connect wallet and sign ───────────────────────────────────
      setStep("signing");
      setStatusText("Please sign the message in your wallet…");

      const provider = await (
        web3Auth as unknown as { connect: () => Promise<unknown> }
      ).connect();

      if (!provider) throw new Error("Web3Auth modal closed before signing.");

      const providerWithRequest = provider as {
        request?: (args: unknown) => Promise<unknown>;
      };

      if (typeof providerWithRequest.request !== "function") {
        throw new Error("Connected wallet does not support signing.");
      }

      let signature: string | null = null;
      try {
        const result = await providerWithRequest.request({
          method: "personal_sign",
          params: [startData.message, walletAddress],
        });
        signature = typeof result === "string" ? result : null;
      } catch {
        const result = await providerWithRequest.request({
          method: "eth_sign",
          params: [walletAddress, startData.message],
        });
        signature = typeof result === "string" ? result : null;
      }

      if (!signature) throw new Error("Wallet did not return a signature.");

      // ── 4. Complete on backend ───────────────────────────────────────
      setStep("completing");
      setStatusText("Completing sign-in…");

      const completeRes = await fetch(
        `${EXCHANGE_SERVER_URL}/monerium/siwe/complete`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            message: startData.message,
            signature,
            state: startData.state,
            walletAddress,
          }),
        },
      );

      if (!completeRes.ok) {
        const err = await completeRes.json().catch(() => null);
        throw new Error(
          err?.error?.message ?? "SIWE authentication failed on backend.",
        );
      }

      const completeData = (await completeRes.json()).data as CompleteData;

      // ── 5. Return to app ─────────────────────────────────────────────
      setStep("done");
      setStatusText("Returning to app…");

      if (completeData.redirectUrl) {
        try {
          sessionStorage.removeItem(SIWE_PARAMS_SESSION_KEY);
          localStorage.removeItem(SIWE_PARAMS_LOCAL_KEY);
          window.location.assign(completeData.redirectUrl);
        } catch {
          // ignore
        }
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      console.error("[MoneriumSiwe]", msg);
      fail(msg);
    }
  }, [userId, walletAddress, appRedirectUri, orderId, fail]);

  useEffect(() => {
    if (startedRef.current) return;
    startedRef.current = true;
    run();
  }, [run]);

  return (
    <div
      style={{
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        minHeight: "100vh",
        fontFamily: "system-ui, sans-serif",
        background: "#0f172a",
        color: "#e2e8f0",
        gap: 16,
        padding: 24,
      }}
    >
      {step !== "error" && <div style={{ fontSize: 32 }}>⏳</div>}
      {step === "error" && <div style={{ fontSize: 32 }}>❌</div>}
      <p style={{ fontSize: 16, textAlign: "center", maxWidth: 320 }}>
        {step === "error" ? errorMsg : statusText}
      </p>
      {step === "error" && appRedirectUri && (
        <p style={{ fontSize: 13, color: "#94a3b8" }}>
          Returning to app shortly…
        </p>
      )}
    </div>
  );
}
