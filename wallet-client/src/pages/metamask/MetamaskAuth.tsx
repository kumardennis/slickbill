import { WEB3AUTH_NETWORK } from "@web3auth/base";
import { Web3Auth } from "@web3auth/modal";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import logo from "../../assets/logo_icon.png";
import { sb } from "../../theme";

type InitState = "idle" | "initializing" | "ready" | "error";
type AuthState = "idle" | "authenticating" | "authenticated" | "error";
type PaymentKind = "pay" | "withdraw" | "link";

type PaymentPreview = {
  amount: string | null;
  payee: string | null;
  iban: string | null;
  ref: string | null;
  kind: PaymentKind;
};

const sessionStorageKeys = {
  callbackUri: "sb_metamask_callback_uri",
  flowMode: "sb_metamask_flow_mode",
  signMessage: "sb_metamask_sign_message",
  amount: "sb_pay_amount",
  payee: "sb_pay_payee",
  iban: "sb_pay_iban",
  ref: "sb_pay_ref",
  kind: "sb_pay_kind",
} as const;

declare global {
  interface Window {
    getMetaMaskInitStateOutOfWeb?: () => InitState;
    getMetaMaskAuthStateOutOfWeb?: () => AuthState;
    getMetaMaskAddressOutOfWeb?: () => string | null;
  }
}

function readQueryOrSession(key: string, sessionKey: string): string | null {
  const params = new URLSearchParams(window.location.search);
  const fromQuery = params.get(key)?.trim();
  if (fromQuery) return fromQuery;
  return window.sessionStorage.getItem(sessionKey)?.trim() || null;
}

function readFlowMode(): "connect" | "sign" {
  const params = new URLSearchParams(window.location.search);
  const mode =
    params.get("mode")?.trim().toLowerCase() ||
    window.sessionStorage.getItem(sessionStorageKeys.flowMode)?.trim().toLowerCase();
  return mode === "sign" ? "sign" : "connect";
}

function readPaymentPreview(): PaymentPreview {
  const kindRaw = (
    readQueryOrSession("kind", sessionStorageKeys.kind) || ""
  ).toLowerCase();
  const kind: PaymentKind =
    kindRaw === "withdraw" ? "withdraw" : kindRaw === "pay" ? "pay" : "link";

  return {
    amount: readQueryOrSession("amount", sessionStorageKeys.amount),
    payee: readQueryOrSession("payee", sessionStorageKeys.payee),
    iban: readQueryOrSession("iban", sessionStorageKeys.iban),
    ref: readQueryOrSession("ref", sessionStorageKeys.ref),
    kind,
  };
}

function persistPaymentPreview(preview: PaymentPreview) {
  const entries: Array<[string, string | null]> = [
    [sessionStorageKeys.amount, preview.amount],
    [sessionStorageKeys.payee, preview.payee],
    [sessionStorageKeys.iban, preview.iban],
    [sessionStorageKeys.ref, preview.ref],
    [sessionStorageKeys.kind, preview.kind],
  ];
  for (const [key, value] of entries) {
    if (value) {
      window.sessionStorage.setItem(key, value);
    }
  }
}

function clearSessionKeys() {
  Object.values(sessionStorageKeys).forEach((key) => {
    window.sessionStorage.removeItem(key);
  });
}

function formatAmount(raw: string | null): string | null {
  if (!raw) return null;
  const trimmed = raw.trim();
  if (!trimmed) return null;
  if (/^[€$£]/.test(trimmed) || /^EUR\s/i.test(trimmed)) return trimmed;
  const n = Number(trimmed.replace(",", "."));
  if (!Number.isFinite(n)) return trimmed;
  return `€${n.toFixed(2)}`;
}

function isUserCancel(message: string): boolean {
  return /user rejected|user denied|user closed|modal closed|closed before|cancelled|canceled/i.test(
    message,
  );
}

function DetailRow({
  label,
  value,
}: {
  label: string;
  value: string;
}) {
  return (
    <div
      style={{
        display: "flex",
        justifyContent: "space-between",
        gap: 16,
        padding: "10px 0",
        borderTop: `1px solid ${sb.outlineVariant}`,
        fontSize: 14,
        lineHeight: 1.4,
      }}
    >
      <span style={{ color: sb.onSurfaceVariant }}>{label}</span>
      <span
        style={{
          color: sb.onSurface,
          fontWeight: 600,
          textAlign: "right",
          wordBreak: "break-word",
        }}
      >
        {value}
      </span>
    </div>
  );
}

export function MetamaskAuth() {
  const [initState, setInitState] = useState<InitState>("idle");
  const [authState, setAuthState] = useState<AuthState>("idle");
  const [walletAddress, setWalletAddress] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [isConnecting, setIsConnecting] = useState(false);
  const [isSignFlow] = useState(() => readFlowMode() === "sign");
  const [paymentPreview] = useState<PaymentPreview>(() => readPaymentPreview());
  const web3AuthRef = useRef<Web3Auth | null>(null);
  const initStartedRef = useRef(false);
  const connectInFlightRef = useRef(false);
  const completionInFlightRef = useRef(false);
  const callbackSentRef = useRef(false);
  const authCompletedRef = useRef(false);

  const callbackUri = useRef<string | null>(null);
  const flowMode = useRef<"connect" | "sign">(isSignFlow ? "sign" : "connect");
  const signMessageRef = useRef<string | null>(null);
  const completeWithProviderRef = useRef<
    ((provider: unknown) => Promise<void>) | null
  >(null);

  const amountLabel = formatAmount(paymentPreview.amount);
  const hasPaymentDetails = Boolean(
    amountLabel || paymentPreview.payee || paymentPreview.iban,
  );

  const copy = useMemo(() => {
    if (!isSignFlow) {
      return {
        title: "Connect wallet",
        subtitle: "Choose how you want to sign in to SlickBills.",
        cta: "Connect wallet",
        trust: "Your keys stay in your wallet. SlickBills never stores them.",
      };
    }
    if (paymentPreview.kind === "withdraw") {
      return {
        title: "Confirm withdrawal",
        subtitle: "Review the bank details, then confirm to send euros.",
        cta: "Confirm withdrawal",
        trust:
          "This authorizes a SEPA transfer to your saved bank account. SlickBills never holds your money.",
      };
    }
    if (hasPaymentDetails) {
      return {
        title: "Confirm payment",
        subtitle: "Review the details, then confirm to send euros.",
        cta: "Confirm payment",
        trust:
          "This authorizes a SEPA euro transfer from your Monerium account. SlickBills never holds your money.",
      };
    }
    return {
      title: "Confirm wallet",
      subtitle: "Confirm you own this wallet to continue.",
      cta: "Confirm wallet",
      trust:
        "This proves you own the wallet linked to your Monerium euro account.",
    };
  }, [hasPaymentDetails, isSignFlow, paymentPreview.kind]);

  const statusCopy = useMemo(() => {
    if (initState === "initializing") {
      return isSignFlow
        ? "Preparing a secure confirmation…"
        : "Preparing a secure connection…";
    }
    if (authState === "authenticating") {
      return isSignFlow
        ? "Waiting for you to confirm…"
        : "Waiting for you to connect…";
    }
    if (authState === "authenticated") {
      return "Confirmed. Returning to SlickBills…";
    }
    return null;
  }, [authState, initState, isSignFlow]);

  useEffect(() => {
    document.title = `${copy.title} · SlickBills`;
  }, [copy.title]);

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
        clearSessionKeys();
      } catch {
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
        request?: (args: { method: string; params?: unknown }) => Promise<unknown>;
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
            });
            return typeof signed === "string" ? signed : null;
          } catch {
            const signed = await providerWithRequest.request({
              method: "eth_sign",
              params: [address, message],
            });
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
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        setErrorMessage(
          isUserCancel(message)
            ? "Confirmation was cancelled. You can try again."
            : message,
        );
        setAuthState("error");
        throw err;
      } finally {
        completionInFlightRef.current = false;
      }
    },
    [returnToCallback],
  );

  completeWithProviderRef.current = completeWithProvider;

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
      const cancelled = isUserCancel(message);
      setErrorMessage(
        cancelled
          ? "Confirmation was cancelled. You can try again."
          : message,
      );
      setAuthState("error");
      if (!cancelled) {
        returnToCallback({
          success: "0",
          error: message,
        });
      }
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
        persistPaymentPreview(readPaymentPreview());

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
            appName: "SlickBills",
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

        const connected = Boolean(
          (web3Auth as unknown as { connected?: boolean }).connected,
        );
        const existingProvider = (
          web3Auth as unknown as { provider?: unknown }
        ).provider;

        web3AuthRef.current = web3Auth;
        setInitState("ready");

        if (
          flowMode.current === "sign" &&
          connected &&
          existingProvider
        ) {
          setAuthState("authenticating");
          try {
            await completeWithProviderRef.current?.(existingProvider);
          } catch {
            setAuthState("error");
          }
          return;
        }

        // Connect (link) flow: always start fresh so the right account is chosen.
        if (connected) {
          console.log(
            "[MetaMaskWeb3Auth] existing session found — logging out to force fresh login",
          );
          try {
            await web3Auth.logout({ cleanup: true });
          } catch {
            // logout may throw if session is already stale; safe to ignore
          }
        }

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

    void initAndConnect();

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

  const showCta =
    (authState === "idle" || authState === "error") && initState === "ready";
  const busy =
    initState === "initializing" ||
    authState === "authenticating" ||
    authState === "authenticated";

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
        background:
          "linear-gradient(180deg, #F4FAFB 0%, #EEF6F8 48%, #F7FBFC 100%)",
        color: sb.onSurface,
        fontFamily: "Inter, system-ui, sans-serif",
      }}
    >
      <div
        style={{
          width: "100%",
          maxWidth: 420,
          borderRadius: 16,
          border: `1px solid ${sb.outlineVariant}`,
          background: sb.surfaceLowest,
          boxShadow: "0 8px 28px rgba(0, 52, 83, 0.06)",
          padding: 24,
        }}
      >
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 10,
          }}
        >
          <img
            src={logo}
            alt="SlickBills"
            width={32}
            height={32}
            style={{ borderRadius: 8 }}
          />
          <span
            style={{
              fontSize: 13,
              fontWeight: 700,
              letterSpacing: 0.2,
              color: sb.deepNavy,
            }}
          >
            SlickBills
          </span>
        </div>

        <h1
          style={{
            margin: "18px 0 0",
            fontSize: 24,
            lineHeight: 1.2,
            fontWeight: 700,
            color: sb.onSurface,
          }}
        >
          {copy.title}
        </h1>
        <p
          style={{
            marginTop: 8,
            marginBottom: 0,
            fontSize: 15,
            lineHeight: 1.5,
            color: sb.onSurfaceVariant,
          }}
        >
          {copy.subtitle}
        </p>

        {hasPaymentDetails ? (
          <div
            style={{
              marginTop: 20,
              padding: "16px 16px 6px",
              borderRadius: 14,
              border: `1px solid ${sb.outlineVariant}`,
              background: sb.surface,
            }}
          >
            {amountLabel ? (
              <div
                style={{
                  fontSize: 32,
                  fontWeight: 700,
                  letterSpacing: -0.6,
                  color: sb.deepNavy,
                  paddingBottom: 12,
                }}
              >
                {amountLabel}
              </div>
            ) : null}
            {paymentPreview.payee ? (
              <DetailRow
                label={paymentPreview.kind === "withdraw" ? "To account" : "To"}
                value={paymentPreview.payee}
              />
            ) : null}
            {paymentPreview.iban ? (
              <DetailRow label="IBAN" value={paymentPreview.iban} />
            ) : null}
            {paymentPreview.ref ? (
              <DetailRow label="Reference" value={paymentPreview.ref} />
            ) : null}
          </div>
        ) : null}

        {statusCopy ? (
          <div
            style={{
              marginTop: 18,
              width: "100%",
              borderRadius: 12,
              border: `1px solid ${sb.outlineVariant}`,
              background: sb.surface,
              color: sb.onSurfaceVariant,
              padding: "14px 16px",
              fontSize: 14,
              fontWeight: 600,
              textAlign: "center",
            }}
          >
            {statusCopy}
          </div>
        ) : null}

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

        {showCta ? (
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
            {isConnecting ? "Opening confirmation…" : copy.cta}
          </button>
        ) : null}

        {!busy || authState === "authenticated" ? (
          <p
            style={{
              marginTop: 16,
              marginBottom: 0,
              fontSize: 12,
              lineHeight: 1.5,
              color: sb.outline,
              textAlign: "center",
            }}
          >
            {copy.trust}
          </p>
        ) : null}
      </div>
    </div>
  );
}
