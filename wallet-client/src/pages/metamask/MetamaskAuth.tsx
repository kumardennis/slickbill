import { WEB3AUTH_NETWORK } from "@web3auth/base";
import { Web3Auth } from "@web3auth/modal";
import { useCallback, useEffect, useRef, useState } from "react";
import { sb } from "../../theme";

type InitState = "idle" | "initializing" | "ready" | "error";
type AuthState = "idle" | "authenticating" | "authenticated" | "error";
const sessionStorageKeys = {
  callbackUri: "sb_metamask_callback_uri",
  flowMode: "sb_metamask_flow_mode",
  signMessage: "sb_metamask_sign_message",
} as const;

declare global {
  interface Window {
    getMetaMaskInitStateOutOfWeb?: () => InitState;
    getMetaMaskAuthStateOutOfWeb?: () => AuthState;
    getMetaMaskAddressOutOfWeb?: () => string | null;
  }
}

export function MetamaskAuth() {
  const [initState, setInitState] = useState<InitState>("idle");
  const [authState, setAuthState] = useState<AuthState>("idle");
  const [walletAddress, setWalletAddress] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [isConnecting, setIsConnecting] = useState(false);
  const web3AuthRef = useRef<Web3Auth | null>(null);
  const initStartedRef = useRef(false);
  const connectInFlightRef = useRef(false);
  const completionInFlightRef = useRef(false);
  const callbackSentRef = useRef(false);
  const authCompletedRef = useRef(false);

  const callbackUri = useRef<string | null>(null);
  const flowMode = useRef<"connect" | "sign">("connect");
  const signMessageRef = useRef<string | null>(null);

  const buildCallbackUrl = useCallback((params: Record<string, string>) => {
    const base = callbackUri.current;
    if (!base) return null;

    try {
      const parsed = new URL(base);
      Object.entries(params).forEach(([key, value]) => {
        parsed.searchParams.set(key, value);
      });
      return parsed.toString();
    } catch {
      return null;
    }
  }, []);

  const returnToCallback = useCallback(
    (params: Record<string, string>) => {
      if (callbackSentRef.current) {
        return;
      }

      const callbackUrl = buildCallbackUrl(params);
      if (!callbackUrl) return;

      callbackSentRef.current = true;

      try {
        window.location.assign(callbackUrl);
        window.sessionStorage.removeItem(sessionStorageKeys.callbackUri);
        window.sessionStorage.removeItem(sessionStorageKeys.flowMode);
        window.sessionStorage.removeItem(sessionStorageKeys.signMessage);
      } catch {
        // Ignore failures when callback URL cannot be opened.
        callbackSentRef.current = false;
      }
    },
    [buildCallbackUrl],
  );

  const completeWithProvider = useCallback(
    async (provider: unknown) => {
      if (authCompletedRef.current || completionInFlightRef.current) {
        return;
      }

      completionInFlightRef.current = true;
      const providerWithRequest = provider as {
        request?: (args: { method: string }) => Promise<unknown>;
        accounts?: unknown;
        selectedAddress?: unknown;
        address?: unknown;
      };

      try {
        let accounts: string[] = [];

        if (typeof providerWithRequest.request === "function") {
          const accountsRaw = (await providerWithRequest.request({
            method: "eth_accounts",
          })) as unknown;

          accounts = Array.isArray(accountsRaw)
            ? accountsRaw.filter(
                (value): value is string => typeof value === "string",
              )
            : [];
        }

        const providerAccounts = Array.isArray(providerWithRequest.accounts)
          ? providerWithRequest.accounts.filter(
              (value): value is string => typeof value === "string",
            )
          : [];

        const candidateAddress =
          accounts[0] ??
          providerAccounts[0] ??
          (typeof providerWithRequest.selectedAddress === "string"
            ? providerWithRequest.selectedAddress
            : undefined) ??
          (typeof providerWithRequest.address === "string"
            ? providerWithRequest.address
            : undefined);

        const address = candidateAddress?.trim();

        if (!address) {
          throw new Error(
            "No wallet address returned by authenticated provider",
          );
        }

        const signIfNeeded = async () => {
          if (flowMode.current !== "sign") return null;

          const message = signMessageRef.current?.trim();
          if (!message) {
            throw new Error("Missing sign_message for wallet signing flow.");
          }

          if (typeof providerWithRequest.request !== "function") {
            throw new Error(
              "Connected wallet provider does not support signing.",
            );
          }

          try {
            const signed = await providerWithRequest.request({
              method: "personal_sign",
              params: [message, address],
            } as unknown as { method: string });
            return typeof signed === "string" ? signed : null;
          } catch {
            const signed = await providerWithRequest.request({
              method: "eth_sign",
              params: [address, message],
            } as unknown as { method: string });
            return typeof signed === "string" ? signed : null;
          }
        };

        const signature = await signIfNeeded();
        if (flowMode.current === "sign" && !signature) {
          throw new Error("Wallet signature was not returned.");
        }

        setWalletAddress(address);
        setAuthState("authenticated");
        authCompletedRef.current = true;

        const payload = {
          type: "SB_METAMASK_AUTH",
          provider: "metamask",
          success: true,
          address,
        };

        try {
          window.postMessage(payload, "*");
        } catch {
          // Ignore postMessage failures in restricted contexts.
        }

        try {
          window.dispatchEvent(
            new CustomEvent("SB_METAMASK_AUTH", {
              detail: payload,
            }),
          );
        } catch {
          // Ignore CustomEvent failures in older environments.
        }

        returnToCallback({
          success: "1",
          provider: "metamask",
          address,
          ...(flowMode.current === "sign" && signature
            ? { signature, flow: "sign" }
            : {}),
        });
      } finally {
        completionInFlightRef.current = false;
      }
    },
    [returnToCallback],
  );

  const connectAndGetAddress = useCallback(async () => {
    const web3Auth = web3AuthRef.current;
    if (!web3Auth || isConnecting || connectInFlightRef.current) return;

    connectInFlightRef.current = true;
    setIsConnecting(true);
    setAuthState("authenticating");
    setErrorMessage(null);

    try {
      const provider = await (
        web3Auth as unknown as {
          connect: () => Promise<unknown>;
        }
      ).connect();

      if (!provider) {
        throw new Error("Web3Auth modal closed before a wallet connected.");
      }

      await completeWithProvider(provider);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      setErrorMessage(message);
      setAuthState("error");
      returnToCallback({
        success: "0",
        error: message,
      });
      console.error("[MetaMaskWeb3Auth] login failed", err);
    } finally {
      connectInFlightRef.current = false;
      setIsConnecting(false);
    }
  }, [completeWithProvider, isConnecting, returnToCallback]);

  useEffect(() => {
    if (initStartedRef.current) {
      return;
    }
    initStartedRef.current = true;

    let cancelled = false;

    const initAndConnect = async () => {
      setInitState("initializing");
      setErrorMessage(null);

      try {
        const params = new URLSearchParams(window.location.search);
        const callbackFromQuery = params.get("callback_uri")?.trim();
        const modeFromQuery = params.get("mode")?.trim().toLowerCase();
        const signMessageFromQuery = params.get("sign_message")?.trim();
        const callbackFromSession = window.sessionStorage
          .getItem(sessionStorageKeys.callbackUri)
          ?.trim();
        const modeFromSession = window.sessionStorage
          .getItem(sessionStorageKeys.flowMode)
          ?.trim()
          .toLowerCase();
        const signMessageFromSession = window.sessionStorage
          .getItem(sessionStorageKeys.signMessage)
          ?.trim();

        flowMode.current =
          modeFromQuery === "sign" || modeFromSession === "sign"
            ? "sign"
            : "connect";
        signMessageRef.current =
          signMessageFromQuery || signMessageFromSession || null;

        callbackUri.current =
          callbackFromQuery && callbackFromQuery.length > 0
            ? callbackFromQuery
            : callbackFromSession && callbackFromSession.length > 0
              ? callbackFromSession
              : null;

        if (callbackUri.current) {
          window.sessionStorage.setItem(
            sessionStorageKeys.callbackUri,
            callbackUri.current,
          );
        }
        window.sessionStorage.setItem(
          sessionStorageKeys.flowMode,
          flowMode.current,
        );
        if (signMessageRef.current) {
          window.sessionStorage.setItem(
            sessionStorageKeys.signMessage,
            signMessageRef.current,
          );
        }

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

        if (!clientId || clientId.trim().length === 0) {
          throw new Error("Missing VITE_WEB3AUTH_CLIENT_ID");
        }

        const web3Auth = new Web3Auth({
          clientId,
          web3AuthNetwork: resolvedNetwork,
          uiConfig: {
            uxMode: "redirect",
          },
          modalConfig: {
            hideWalletDiscovery: false,
            connectors: {
              auth: {
                label: "Web3Auth",
                showOnModal: true,
                loginMethods: {
                  google: {
                    name: "Google",
                    showOnModal: true,
                  },
                },
              },
              metamask: {
                label: "MetaMask",
                showOnModal: true,
              },
              "wallet-connect-v2": {
                label: "WalletConnect",
                showOnModal: true,
              },
            },
          },
        });

        await web3Auth.init();
        if (cancelled) return;

        // If Web3Auth cached a previous session (different Slickbill account),
        // log it out immediately so the modal always shows fresh.
        if ((web3Auth as unknown as { connected?: boolean }).connected) {
          console.log(
            "[MetaMaskWeb3Auth] existing session found — logging out to force fresh login",
          );
          try {
            await web3Auth.logout({ cleanup: true });
          } catch {
            // logout may throw if session is already stale; safe to ignore
          }
        }

        web3AuthRef.current = web3Auth;
        setInitState("ready");
        console.log("[MetaMaskWeb3Auth] init completed", {
          network: resolvedNetwork,
        });

        setAuthState("idle");
      } catch (err) {
        if (cancelled) return;
        const message = err instanceof Error ? err.message : String(err);
        setErrorMessage(message);
        setInitState("error");
        setAuthState("error");
        console.error("[MetaMaskWeb3Auth] initialization failed", err);
      }
    };

    initAndConnect();

    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    window.getMetaMaskInitStateOutOfWeb = () => initState;
    window.getMetaMaskAuthStateOutOfWeb = () => authState;
    window.getMetaMaskAddressOutOfWeb = () => walletAddress;

    const payload = {
      type: "SB_METAMASK_INIT",
      provider: "metamask",
      state: initState,
      ready: initState === "ready",
    };

    try {
      window.postMessage(payload, "*");
    } catch {
      // Ignore postMessage failures in restricted contexts.
    }

    try {
      window.dispatchEvent(
        new CustomEvent("SB_METAMASK_INIT", {
          detail: payload,
        }),
      );
    } catch {
      // Ignore CustomEvent failures in older environments.
    }

    return () => {
      delete window.getMetaMaskInitStateOutOfWeb;
      delete window.getMetaMaskAuthStateOutOfWeb;
      delete window.getMetaMaskAddressOutOfWeb;
    };
  }, [initState, authState, walletAddress]);

  return (
    <div
      style={{
        minHeight: "100vh",
        width: "100%",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        padding: 20,
        boxSizing: "border-box",
        background: sb.surface,
        color: sb.onSurface,
        fontFamily: "Inter, system-ui, sans-serif",
      }}
    >
      <div
        style={{
          width: "100%",
          maxWidth: 420,
          borderRadius: 12,
          border: `1px solid ${sb.outlineVariant}`,
          background: sb.surfaceLowest,
          boxShadow: "0 2px 12px rgba(0, 52, 83, 0.04)",
          padding: 24,
        }}
      >
        <div
          style={{
            display: "inline-flex",
            alignItems: "center",
            gap: 8,
            padding: "6px 10px",
            borderRadius: 999,
            background: "rgba(0, 194, 255, 0.12)",
            color: sb.deepNavy,
            fontSize: 12,
            fontWeight: 700,
            letterSpacing: 0.2,
          }}
        >
          Web3Auth
        </div>

        <h2
          style={{
            margin: "14px 0 0",
            fontSize: 24,
            lineHeight: 1.2,
            fontWeight: 700,
            color: sb.onSurface,
          }}
        >
          Connect wallet
        </h2>
        <p
          style={{
            marginTop: 8,
            marginBottom: 0,
            fontSize: 15,
            lineHeight: 1.5,
            color: sb.onSurfaceVariant,
          }}
        >
          {flowMode.current === "sign"
            ? "Open Web3Auth and sign the required Monerium ownership message."
            : "Open Web3Auth and choose how you want to sign in."}
        </p>

        <div
          style={{
            marginTop: 18,
            padding: 14,
            borderRadius: 14,
            border: "1px solid #e2e8f0",
            background: "#f8fafc",
            fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace",
            fontSize: 13,
            lineHeight: 1.7,
            color: "#334155",
          }}
        >
          <div>
            <span style={{ color: "#64748b" }}>init:</span> {initState}
          </div>
          <div>
            <span style={{ color: "#64748b" }}>auth:</span> {authState}
          </div>
          <div>
            <span style={{ color: "#64748b" }}>address:</span>{" "}
            {walletAddress ?? "(pending)"}
          </div>
        </div>

        <p
          style={{
            marginTop: 14,
            marginBottom: 0,
            fontSize: 13,
            lineHeight: 1.5,
            color: "#64748b",
          }}
        >
          Google returns the Web3Auth embedded wallet address. MetaMask and
          WalletConnect return the connected external wallet address.
        </p>

        {authState === "error" && errorMessage ? (
          <div
            style={{
              marginTop: 14,
              padding: 12,
              borderRadius: 12,
              border: "1px solid #fecaca",
              background: "#fef2f2",
              color: "#b91c1c",
              fontSize: 13,
              lineHeight: 1.45,
            }}
          >
            {errorMessage}
          </div>
        ) : null}

        {(authState === "idle" || authState === "error") &&
        initState === "ready" ? (
          <button
            type="button"
            onClick={() => {
              void connectAndGetAddress();
            }}
            disabled={isConnecting}
            style={{
              marginTop: 18,
              width: "100%",
              borderRadius: 12,
              border: "none",
              background: isConnecting ? sb.outlineVariant : sb.deepNavy,
              color: sb.onPrimary,
              padding: "14px 16px",
              fontSize: 15,
              fontWeight: 700,
              letterSpacing: 0.2,
              cursor: isConnecting ? "not-allowed" : "pointer",
              boxShadow: isConnecting
                ? "none"
                : "0 10px 20px rgba(11, 37, 69, 0.2)",
            }}
          >
            {isConnecting ? "Opening Web3Auth..." : "Continue with Web3Auth"}
          </button>
        ) : null}

        {authState === "authenticating" || initState === "initializing" ? (
          <div
            style={{
              marginTop: 18,
              width: "100%",
              borderRadius: 12,
              border: "1px solid #dbe3ef",
              background: "#f1f5f9",
              color: "#334155",
              padding: "14px 16px",
              fontSize: 14,
              fontWeight: 600,
              textAlign: "center",
            }}
          >
            {initState === "initializing"
              ? "Preparing Web3Auth..."
              : "Waiting for wallet..."}
          </div>
        ) : null}

        <p
          style={{
            marginTop: 16,
            marginBottom: 0,
            fontSize: 12,
          color: sb.outline,
          textAlign: "center",
          display: "none",
          }}
        >
          Route: /wallet/metamask-auth
        </p>
      </div>
    </div>
  );
}
