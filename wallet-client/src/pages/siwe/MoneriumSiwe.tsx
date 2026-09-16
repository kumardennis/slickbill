import {
  useCreateWallet,
  useLogin,
  usePrivy,
  useWallets,
} from "@privy-io/react-auth";
import { useCallback, useEffect, useRef, useState } from "react";
import { sb } from "../../theme";
import { expressServerUrl } from "../../config";

const SIWE_PARAMS_SESSION_KEY = "monerium_siwe_params_v1";
const SIWE_PARAMS_LOCAL_KEY = "monerium_siwe_params_v1_local";

type Step = "idle" | "init" | "signing" | "completing" | "done" | "error";

type CompleteData = {
  redirectUrl?: string;
  status?: "success" | "pending" | string;
};

type RpcProvider = {
  request?: (args: { method: string; params?: unknown }) => Promise<unknown>;
};

type SignableWallet = {
  address: string;
  getEthereumProvider: () => Promise<unknown>;
};

export function MoneriumSiwe() {
  const { ready, authenticated } = usePrivy();
  const { login } = useLogin();
  const { wallets, ready: walletsReady } = useWallets();
  const { createWallet } = useCreateWallet();
  const [step, setStep] = useState<Step>("idle");
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [statusText, setStatusText] = useState("Connecting wallet…");

  const loginStartedRef = useRef(false);
  const signStartedRef = useRef(false);

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

      setStep("init");
      setStatusText("Preparing sign-in message…");
      const startRes = await fetch(`${expressServerUrl}/monerium/siwe/start`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          userId,
          walletAddress,
          appRedirectUri,
          orderId,
        }),
      });

      if (!startRes.ok) {
        const err = await startRes.json().catch(() => null);
        throw new Error(err?.error?.message ?? "Failed to start SIWE flow.");
      }

      const startData = (await startRes.json()).data as {
        message: string;
        state: string;
      };

      setStep("signing");
      setStatusText("Please sign the message in your wallet…");

      const wanted = walletAddress.toLowerCase();
      let wallet: SignableWallet | null =
        wallets.find((item) => item.address.toLowerCase() === wanted) ?? null;
      if (!wallet) {
        const created = await createWallet().catch(() => null);
        if (created && created.address.toLowerCase() === wanted) {
          wallet = created;
        }
      }

      if (!wallet || typeof wallet.getEthereumProvider !== "function") {
        throw new Error(
          "Connected wallet does not match the address used to link Monerium.",
        );
      }

      const provider = (await wallet.getEthereumProvider()) as RpcProvider;
      if (typeof provider.request !== "function") {
        throw new Error("Connected wallet does not support signing.");
      }

      let signature: string | null = null;
      try {
        const result = await provider.request({
          method: "personal_sign",
          params: [startData.message, walletAddress],
        });
        signature = typeof result === "string" ? result : null;
      } catch {
        const result = await provider.request({
          method: "eth_sign",
          params: [walletAddress, startData.message],
        });
        signature = typeof result === "string" ? result : null;
      }

      if (!signature) throw new Error("Wallet did not return a signature.");

      setStep("completing");
      setStatusText("Completing sign-in…");

      const completeRes = await fetch(
        `${expressServerUrl}/monerium/siwe/complete`,
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
  }, [
    appRedirectUri,
    createWallet,
    fail,
    orderId,
    persistedParams?.appRedirectUri,
    persistedParams?.orderId,
    persistedParams?.userId,
    persistedParams?.walletAddress,
    rawAppRedirectUri,
    rawOrderId,
    rawUserId,
    rawWalletAddress,
    userId,
    walletAddress,
    wallets,
  ]);

  useEffect(() => {
    if (!ready) return;
    if (!authenticated) {
      if (loginStartedRef.current) return;
      loginStartedRef.current = true;
      setStatusText("Connect wallet…");
      login();
      return;
    }
    if (!walletsReady || signStartedRef.current) return;
    signStartedRef.current = true;
    void run();
  }, [authenticated, login, ready, run, walletsReady]);

  return (
    <div
      style={{
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        minHeight: "100vh",
        fontFamily: "Inter, system-ui, sans-serif",
        background: sb.surface,
        color: sb.onSurface,
        gap: 16,
        padding: 24,
      }}
    >
      {step !== "error" && (
        <div
          style={{
            width: 40,
            height: 40,
            borderRadius: 999,
            border: `3px solid ${sb.outlineVariant}`,
            borderTopColor: sb.electricCyan,
            animation: "sb-spin 0.8s linear infinite",
          }}
        />
      )}
      <p
        style={{
          fontSize: 16,
          fontWeight: 600,
          textAlign: "center",
          maxWidth: 320,
          color: step === "error" ? sb.error : sb.onSurface,
        }}
      >
        {step === "error" ? errorMsg : statusText}
      </p>
      {step === "error" && appRedirectUri && (
        <p style={{ fontSize: 13, color: sb.onSurfaceVariant }}>
          Returning to the app shortly…
        </p>
      )}
      <style>{`@keyframes sb-spin { to { transform: rotate(360deg); } }`}</style>
    </div>
  );
}
