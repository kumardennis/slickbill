import {
  useCreateWallet,
  useLogin,
  usePrivy,
  useWallets,
} from "@privy-io/react-auth";
import { useCallback, useEffect, useRef, useState } from "react";
import logo from "../../assets/logo_icon.png";
import { sb } from "../../theme";

type RpcProvider = {
  request?: (args: { method: string; params?: unknown }) => Promise<unknown>;
};

const sessionKeys = {
  callbackUri: "sb_privy_callback_uri",
  flowMode: "sb_privy_flow_mode",
  signMessage: "sb_privy_sign_message",
} as const;

function isUserCancel(message: string): boolean {
  return /user rejected|user denied|user closed|cancelled|canceled/i.test(
    message,
  );
}

function hexAddress(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return /^0x[a-fA-F0-9]{40}$/.test(trimmed) ? trimmed : null;
}

export function PrivyAuth() {
  const { ready, authenticated, user } = usePrivy();
  const { login } = useLogin();
  const { wallets, ready: walletsReady } = useWallets();
  const { createWallet } = useCreateWallet();
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [walletAddress, setWalletAddress] = useState<string | null>(null);
  const completingRef = useRef(false);
  const createAttemptedRef = useRef(false);
  const callbackUri = useRef<string | null>(null);
  const flowMode = useRef<"connect" | "sign">("connect");
  const signMessageRef = useRef<string | null>(null);
  const callbackSentRef = useRef(false);

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const callbackFromQuery = params.get("callback_uri")?.trim();
    const modeFromQuery = params.get("mode")?.trim().toLowerCase();
    const signFromQuery = params.get("sign_message")?.trim();
    const callbackFromSession = window.sessionStorage
      .getItem(sessionKeys.callbackUri)
      ?.trim();
    const modeFromSession = window.sessionStorage
      .getItem(sessionKeys.flowMode)
      ?.trim()
      .toLowerCase();
    const signFromSession = window.sessionStorage
      .getItem(sessionKeys.signMessage)
      ?.trim();

    flowMode.current =
      modeFromQuery === "sign" || modeFromSession === "sign"
        ? "sign"
        : "connect";
    signMessageRef.current = signFromQuery || signFromSession || null;
    callbackUri.current =
      callbackFromQuery && callbackFromQuery.length > 0
        ? callbackFromQuery
        : callbackFromSession && callbackFromSession.length > 0
          ? callbackFromSession
          : null;

    if (callbackUri.current) {
      window.sessionStorage.setItem(
        sessionKeys.callbackUri,
        callbackUri.current,
      );
    }
    window.sessionStorage.setItem(sessionKeys.flowMode, flowMode.current);
    if (signMessageRef.current) {
      window.sessionStorage.setItem(
        sessionKeys.signMessage,
        signMessageRef.current,
      );
    }
  }, []);

  const resolveAddress = useCallback((): string | null => {
    const privyWallet = wallets.find(
      (wallet) => wallet.walletClientType === "privy",
    );
    const linkedWallet = user?.linkedAccounts.find(
      (account) => account.type === "wallet",
    );
    return (
      hexAddress(privyWallet?.address) ??
      hexAddress(wallets[0]?.address) ??
      hexAddress(
        linkedWallet && "address" in linkedWallet
          ? linkedWallet.address
          : null,
      )
    );
  }, [user, wallets]);

  const returnToCallback = useCallback((params: Record<string, string>) => {
    if (callbackSentRef.current) return;
    callbackSentRef.current = true;

    const payload: Record<string, unknown> = {
      type: "SB_METAMASK_AUTH",
      provider: "privy",
      success: params.success !== "0",
      ...(params.address ? { address: params.address } : {}),
      ...(params.signature ? { signature: params.signature } : {}),
      ...(params.flow ? { flow: params.flow } : {}),
      ...(params.error ? { error: params.error } : {}),
    };

    try {
      const opener = window.opener as Window | null;
      if (opener && !opener.closed) {
        opener.postMessage(payload, "*");
      }
    } catch {
      // Ignore opener access errors.
    }

    try {
      const channel = new BroadcastChannel("slickbills-wallet");
      channel.postMessage(payload);
      channel.close();
    } catch {
      // Ignore if BroadcastChannel is unavailable.
    }

    const base = callbackUri.current;
    if (!base) {
      callbackSentRef.current = false;
      return;
    }

    try {
      const parsed = new URL(base);
      Object.entries(params).forEach(([key, value]) => {
        parsed.searchParams.set(key, value);
      });
      window.location.assign(parsed.toString());
    } catch {
      callbackSentRef.current = false;
    }
  }, []);

  const completeWithAddress = useCallback(
    async (address: string) => {
      if (completingRef.current) return;
      completingRef.current = true;
      setWalletAddress(address);
      setErrorMessage(null);

      try {
        let signature: string | null = null;
        if (flowMode.current === "sign") {
          const message = signMessageRef.current?.trim();
          if (!message) {
            throw new Error("Missing sign_message for wallet signing flow.");
          }
          const wallet =
            wallets.find((item) => item.walletClientType === "privy") ??
            wallets[0];
          if (!wallet || typeof wallet.getEthereumProvider !== "function") {
            throw new Error("Privy wallet does not support signing.");
          }
          const provider = (await wallet.getEthereumProvider()) as RpcProvider;
          if (typeof provider.request !== "function") {
            throw new Error("Privy wallet provider is not ready.");
          }
          const signed = await provider.request({
            method: "personal_sign",
            params: [message, address],
          });
          if (typeof signed !== "string" || !signed.trim()) {
            throw new Error("Wallet signature was not returned.");
          }
          signature = signed;
        }

        returnToCallback({
          success: "1",
          provider: "privy",
          address,
          ...(signature ? { signature, flow: "sign" } : {}),
        });
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        setErrorMessage(
          isUserCancel(message)
            ? "Confirmation was cancelled. You can try again."
            : message,
        );
        completingRef.current = false;
      }
    },
    [returnToCallback, wallets],
  );

  useEffect(() => {
    if (!ready || !authenticated || !walletsReady || completingRef.current) {
      return;
    }

    let cancelled = false;
    void (async () => {
      let address = resolveAddress();
      if (!address && !createAttemptedRef.current) {
        createAttemptedRef.current = true;
        try {
          const created = await createWallet();
          address = hexAddress(created?.address);
        } catch {
          address = resolveAddress();
        }
      }
      if (cancelled) return;
      if (address) {
        await completeWithAddress(address);
        return;
      }
      setErrorMessage("Signed in, but no wallet address came back.");
    })();

    return () => {
      cancelled = true;
    };
  }, [
    authenticated,
    completeWithAddress,
    createWallet,
    ready,
    resolveAddress,
    walletsReady,
  ]);

  const statusCopy = !ready
    ? "Preparing a secure connection…"
    : walletAddress
      ? "Confirmed. Returning to SlickBills…"
      : null;

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
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
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
          Connect wallet
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
          Google, MetaMask, Rabby, WalletConnect, and other Ethereum wallets.
          Web3Auth is unchanged at /wallet/metamask-auth. Facebook is not a
          native Privy login.
        </p>

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

        {walletAddress ? (
          <div
            style={{
              marginTop: 16,
              padding: 14,
              borderRadius: 12,
              border: `1px solid ${sb.outlineVariant}`,
              background: "#ecfdf3",
              color: "#166534",
              fontSize: 13,
              lineHeight: 1.45,
              wordBreak: "break-all",
            }}
          >
            <div style={{ fontWeight: 700, marginBottom: 6 }}>Wallet address</div>
            {walletAddress}
          </div>
        ) : null}

        {errorMessage ? (
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

        {ready && !authenticated ? (
          <button
            type="button"
            onClick={() => {
              setErrorMessage(null);
              login();
            }}
            style={{
              marginTop: 18,
              width: "100%",
              borderRadius: 12,
              border: "none",
              background: sb.deepNavy,
              color: sb.onPrimary,
              padding: "14px 16px",
              fontSize: 15,
              fontWeight: 700,
              letterSpacing: 0.2,
              cursor: "pointer",
              boxShadow: "0 10px 20px rgba(11, 37, 69, 0.2)",
            }}
          >
            Connect wallet
          </button>
        ) : null}
      </div>
    </div>
  );
}
