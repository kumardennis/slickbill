import {
  useCreateWallet,
  useLogin,
  useLoginWithOAuth,
  useLogout,
  usePrivy,
  useWallets,
  type User,
} from "@privy-io/react-auth";
import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type CSSProperties,
} from "react";
import logo from "../../assets/logo_icon.png";
import { sb } from "../../theme";
import {
  clearLoginStarted,
  loginWasStarted,
  markLoginStarted,
  readLastUsedAccount,
  shortenAddress,
  writeLastUsedAccount,
  type LastUsedAccount,
} from "./accountChoice";

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

function identityFromUser(
  user: User | null,
  address: string | null,
): LastUsedAccount {
  return {
    email: user?.google?.email || user?.email?.address || undefined,
    name: user?.google?.name || undefined,
    address: address || undefined,
  };
}

function lastUsedTitle(account: LastUsedAccount): string {
  return account.name || account.email || "Last used account";
}

function lastUsedSubtitle(account: LastUsedAccount): string | null {
  const lines = [
    account.email && account.name ? account.email : null,
    account.address ? shortenAddress(account.address) : null,
  ].filter(Boolean);
  return lines.length > 0 ? lines.join(" · ") : null;
}

const primaryButtonStyle: CSSProperties = {
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
};

const secondaryButtonStyle: CSSProperties = {
  marginTop: 10,
  width: "100%",
  borderRadius: 12,
  border: `1px solid ${sb.outlineVariant}`,
  background: sb.surfaceLowest,
  color: sb.deepNavy,
  padding: "14px 16px",
  fontSize: 15,
  fontWeight: 700,
  letterSpacing: 0.2,
  cursor: "pointer",
};

export function PrivyAuth() {
  const { ready, authenticated, user } = usePrivy();
  const { login } = useLogin({
    onComplete: ({ wasAlreadyAuthenticated }) => {
      if (wasAlreadyAuthenticated) return;
      markLoginStarted();
      setAutoAfterLogin(true);
    },
    onError: (error) => {
      const message = String(error);
      if (!isUserCancel(message)) {
        setErrorMessage(message);
      }
      clearLoginStarted();
      setAutoAfterLogin(false);
      setBusy(false);
    },
  });
  const { initOAuth } = useLoginWithOAuth({
    onComplete: ({ wasAlreadyAuthenticated }) => {
      if (wasAlreadyAuthenticated) return;
      markLoginStarted();
      setAutoAfterLogin(true);
    },
    onError: (error) => {
      const message = String(error);
      if (!isUserCancel(message)) {
        setErrorMessage(message);
      }
      clearLoginStarted();
      setAutoAfterLogin(false);
      setBusy(false);
    },
  });
  const { logout } = useLogout();
  const { wallets, ready: walletsReady } = useWallets();
  const { createWallet } = useCreateWallet();
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [walletAddress, setWalletAddress] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [autoAfterLogin, setAutoAfterLogin] = useState(loginWasStarted);
  const [storedLastUsed, setStoredLastUsed] = useState<LastUsedAccount | null>(
    readLastUsedAccount,
  );
  const completingRef = useRef(false);
  const createAttemptedRef = useRef(false);
  const callbackUri = useRef<string | null>(null);
  const [flowMode, setFlowMode] = useState<"connect" | "sign">(() => {
    try {
      const params = new URLSearchParams(window.location.search);
      const fromQuery = params.get("mode")?.trim().toLowerCase();
      const fromSession = window.sessionStorage
        .getItem(sessionKeys.flowMode)
        ?.trim()
        .toLowerCase();
      return fromQuery === "sign" || fromSession === "sign" ? "sign" : "connect";
    } catch {
      return "connect";
    }
  });
  const flowModeRef = useRef<"connect" | "sign">(flowMode);
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

    const nextMode: "connect" | "sign" =
      modeFromQuery === "sign" || modeFromSession === "sign"
        ? "sign"
        : "connect";
    flowModeRef.current = nextMode;
    setFlowMode(nextMode);
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
    window.sessionStorage.setItem(sessionKeys.flowMode, nextMode);
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

  const lastUsed = useMemo(() => {
    const live = identityFromUser(user ?? null, resolveAddress());
    const merged: LastUsedAccount = { ...storedLastUsed };
    if (live.email) merged.email = live.email;
    if (live.name) merged.name = live.name;
    if (live.address) merged.address = live.address;
    return merged.email || merged.name || merged.address ? merged : null;
  }, [resolveAddress, storedLastUsed, user]);

  useEffect(() => {
    if (!user && !resolveAddress()) return;
    const next = identityFromUser(user ?? null, resolveAddress());
    writeLastUsedAccount(next);
    setStoredLastUsed(readLastUsedAccount());
  }, [resolveAddress, user]);

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
      writeLastUsedAccount(identityFromUser(user ?? null, address));
      setStoredLastUsed(readLastUsedAccount());

      try {
        let signature: string | null = null;
        if (flowModeRef.current === "sign") {
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
        setBusy(false);
      }
    },
    [returnToCallback, user, wallets],
  );

  const proceedWithWallet = useCallback(async () => {
    if (!ready || !authenticated || !walletsReady || completingRef.current) {
      return;
    }

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
    if (address) {
      await completeWithAddress(address);
      return;
    }
    setErrorMessage("Signed in, but no wallet address came back.");
    setBusy(false);
  }, [
    authenticated,
    completeWithAddress,
    createWallet,
    ready,
    resolveAddress,
    walletsReady,
  ]);

  const shouldAutoComplete = flowMode === "sign" || autoAfterLogin;

  useEffect(() => {
    if (!shouldAutoComplete) return;
    void proceedWithWallet();
  }, [proceedWithWallet, shouldAutoComplete]);

  const handleContinueLastUsed = async () => {
    setErrorMessage(null);
    setBusy(true);
    markLoginStarted();
    setAutoAfterLogin(true);
    if (authenticated) {
      await proceedWithWallet();
      return;
    }
    try {
      await initOAuth({ provider: "google" });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      if (!isUserCancel(message)) {
        setErrorMessage(message);
      }
      clearLoginStarted();
      setAutoAfterLogin(false);
      setBusy(false);
    }
  };

  const handleChooseAnother = async () => {
    setErrorMessage(null);
    setBusy(true);
    try {
      if (authenticated) {
        await logout();
      }
      login();
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      if (!isUserCancel(message)) {
        setErrorMessage(message);
      }
      clearLoginStarted();
      setAutoAfterLogin(false);
    } finally {
      setBusy(false);
    }
  };

  const showChoice =
    ready &&
    !walletAddress &&
    flowMode !== "sign" &&
    (!authenticated || !autoAfterLogin);

  const statusCopy = !ready
    ? "Preparing a secure connection…"
    : walletAddress
      ? "Confirmed. Returning to SlickBills…"
      : busy && !showChoice
        ? "Continue in the Google or wallet window…"
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
          Continue with the last Google account, or choose a different Google
          account or wallet.
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

        {showChoice && lastUsed ? (
          <div
            style={{
              marginTop: 18,
              padding: 14,
              borderRadius: 12,
              border: `1px solid ${sb.outlineVariant}`,
              background: sb.surface,
            }}
          >
            <div
              style={{
                fontSize: 11,
                fontWeight: 700,
                letterSpacing: 0.6,
                textTransform: "uppercase",
                color: sb.onSurfaceVariant,
              }}
            >
              Last used
            </div>
            <div
              style={{
                marginTop: 8,
                fontSize: 16,
                fontWeight: 700,
                color: sb.onSurface,
              }}
            >
              {lastUsedTitle(lastUsed)}
            </div>
            {lastUsedSubtitle(lastUsed) ? (
              <div
                style={{
                  marginTop: 4,
                  fontSize: 13,
                  color: sb.onSurfaceVariant,
                  wordBreak: "break-word",
                }}
              >
                {lastUsedSubtitle(lastUsed)}
              </div>
            ) : null}
            <button
              type="button"
              disabled={busy}
              onClick={() => {
                void handleContinueLastUsed();
              }}
              style={{
                ...primaryButtonStyle,
                marginTop: 14,
                opacity: busy ? 0.7 : 1,
              }}
            >
              Continue as{" "}
              {lastUsed.email ||
                lastUsed.name ||
                (lastUsed.address ? shortenAddress(lastUsed.address) : "this account")}
            </button>
          </div>
        ) : null}

        {showChoice ? (
          <button
            type="button"
            disabled={busy}
            onClick={() => {
              void handleChooseAnother();
            }}
            style={{
              ...(lastUsed ? secondaryButtonStyle : primaryButtonStyle),
              opacity: busy ? 0.7 : 1,
            }}
          >
            {lastUsed
              ? "Use another Google account or wallet"
              : "Choose Google account or wallet"}
          </button>
        ) : null}
      </div>
    </div>
  );
}
