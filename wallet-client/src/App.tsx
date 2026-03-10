/* eslint-disable react-hooks/set-state-in-effect */
import "./App.css";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { type Config } from "@coinbase/cdp-react";
import { EURCPayment } from "./pages/pay/EURCPayment.tsx";
import logo from "./assets/logo_icon.png";
import {
  CDPHooksProvider,
  useAuthenticateWithJWT,
  useCurrentUser,
  useIsInitialized,
} from "@coinbase/cdp-hooks";
import { Balance } from "./pages/balance/Balance.tsx";
import { Onramp } from "./pages/onramp/Onramp.tsx";
import { UpgradeToSmartAccount } from "./pages/smart-account/SmartAccountUpgrade.tsx";
import { useEffect, useMemo, useRef, useState } from "react";
import { LinkEmail } from "./pages/link-email/LinkEmail.tsx";

declare global {
  interface Window {
    getAccountAddressOutOfWeb: () => `0x${string}` | null;
    getUserIdOutOfWeb: () => string | null;
    getBalanceOutOfWeb: () => string | null;
    getTxHashOutOfWeb: () => string | null;
    getOnrampUrlOutOfWeb: () => string | null;
    flutterAccessToken?: string;
    isFlutterApp?: boolean;
  }
}

const EXCHANGE_SERVER_URL = "https://express-ten-xi.vercel.app";

function App() {
  const [readyToInit, setReadyToInit] = useState(false);

  const consumeSlickBillsExchangeCodeIfPresent = async () => {
    const params = new URLSearchParams(window.location.search);
    const sb = params.get("sb") === "1";
    const code = params.get("code");

    if (!sb || !code) return;

    // mark embedded mode early so the rest of the app can branch
    window.isFlutterApp = true;

    try {
      const res = await fetch(
        `${EXCHANGE_SERVER_URL}/cdp/exchange-code/consume`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ code }),
        }
      );

      const json = await res.json().catch(() => null);

      console.log("Exchange code consume response:", res.status, json);

      if (!res.ok) {
        console.error("❌ Exchange code consume failed:", res.status, json);
        return;
      }

      const token = json?.token;
      if (typeof token === "string" && token.length > 10) {
        window.flutterAccessToken = token;

        // Remove code from URL (prevents sharing/leaking it)
        params.delete("code");
        const next =
          window.location.pathname +
          (params.toString() ? `?${params.toString()}` : "") +
          window.location.hash;

        window.history.replaceState({}, "", next);
      } else {
        console.error("❌ Exchange code consume returned invalid token:", json);
      }
    } catch (e) {
      console.error("❌ Exchange code consume exception:", e);
    }
  };

  useEffect(() => {
    let cancelled = false;

    const waitForFlutterToken = async () => {
      await consumeSlickBillsExchangeCodeIfPresent();

      if (!window.isFlutterApp) return;

      // wait up to ~6s for Flutter injection
      for (let i = 0; i < 60; i += 1) {
        if (cancelled) return;
        if (window.flutterAccessToken && window.flutterAccessToken.length > 10)
          return;
        await new Promise((r) => setTimeout(r, 100));
      }
    };

    const run = async () => {
      await waitForFlutterToken();
      if (!cancelled) setReadyToInit(true);
    };

    run();

    return () => {
      cancelled = true;
    };
  }, []);

  const cdpConfig: Config | null = useMemo(() => {
    if (!readyToInit) return null;

    console.log("🔧 Initializing CDP Config...");
    console.log("Flutter App?", !!window.isFlutterApp);
    console.log("Access Token present?", !!window.flutterAccessToken);

    const config: Config = {
      projectId: "02466600-f64d-4bfb-b27f-964a9fac5187",
      customAuth: {
        getJwt: async () => {
          if (window.isFlutterApp && window.flutterAccessToken) {
            return window.flutterAccessToken;
          }
          return undefined;
        },
      },
      ethereum: { createOnLogin: "smart" },
      appName: "SlickBills",
      appLogoUrl: "https://www.slickbills.com/logo.png",
    };

    console.log("✅ CDP Config initialized");
    return config;
  }, [readyToInit]);

  if (!cdpConfig) {
    return (
      <div style={styles.centerScreen}>
        <div style={styles.card}>
          <div style={styles.brandRow}>
            <div style={styles.logoMark} aria-hidden />
            <div>
              <div style={styles.brandTitle}>SlickBills</div>
              <div style={styles.brandSubtitle}>Wallet</div>
            </div>
          </div>
          <div style={styles.hr} />
          <div style={styles.muted}>Initializing wallet…</div>
        </div>
      </div>
    );
  }

  return (
    <CDPHooksProvider config={cdpConfig}>
      <BrowserRouter basename="/">
        <AppContent />
      </BrowserRouter>
    </CDPHooksProvider>
  );
}

function AppContent() {
  const { isInitialized } = useIsInitialized();
  const { authenticateWithJWT } = useAuthenticateWithJWT();
  const user = useCurrentUser();
  const authAttemptedRef = useRef(false);

  useEffect(() => {
    if (!isInitialized) return;
    if (!window.isFlutterApp) return;
    if (authAttemptedRef.current) return;

    const waitForTokenAndAuth = async () => {
      try {
        authAttemptedRef.current = true;
        await authenticateWithJWT();
        console.log("✅ authenticateWithJWT success");
      } catch (err) {
        console.error("❌ Auth failed:", err);
        authAttemptedRef.current = false;
      }
    };

    waitForTokenAndAuth();
  }, [authenticateWithJWT, isInitialized]);

  useEffect(() => {
    console.log(
      "Current user:",
      user.currentUser?.authenticationMethods?.google?.email ?? "(none)"
    );

    if (!window.isFlutterApp) return;

    // ✅ Always define all polled functions so Flutter polling never throws
    window.getAccountAddressOutOfWeb = () => {
      const first = user.currentUser?.evmSmartAccounts?.[0];
      const addr = typeof first === "string" ? first : first;
      return (addr as `0x${string}`) ?? null;
    };

    window.getUserIdOutOfWeb = () => user.currentUser?.userId ?? null;

    // Balance page will set this to a real value; default to null.
    window.getBalanceOutOfWeb = window.getBalanceOutOfWeb ?? (() => null);

    // Pay page can override; default null.
    window.getTxHashOutOfWeb = window.getTxHashOutOfWeb ?? (() => null);

    window.getOnrampUrlOutOfWeb = window.getOnrampUrlOutOfWeb ?? (() => null);

    console.log("✅ Flutter functions exposed to window");
  }, [user.currentUser]);

  const currentEmail =
    user.currentUser?.authenticationMethods?.google?.email ?? null;

  return (
    <div style={styles.page}>
      <header style={styles.header}>
        <div style={styles.headerInner}>
          <div style={styles.brandRow}>
            <img
              src={logo}
              alt="SlickBills"
              style={styles.logo}
              loading="eager"
            />
            <div>
              <div style={styles.headerTitle}>SlickBills Wallet</div>
              <div style={styles.headerSubtitle}>
                {window.isFlutterApp ? "Embedded" : "Web"} ·{" "}
                {currentEmail ?? "Not signed in"}
              </div>
            </div>
          </div>

          <div style={styles.statusPill} title="SDK status">
            <span
              style={{
                ...styles.statusDot,
                backgroundColor: isInitialized ? "#16a34a" : "#f59e0b",
              }}
            />
            <span style={styles.statusText}>
              {isInitialized ? "Ready" : "Starting"}
            </span>
          </div>
        </div>
      </header>

      <main style={styles.main}>
        <div style={styles.container}>
          <Routes>
            <Route path="/wallet/balance" element={<BalancePage />} />
            <Route path="/wallet/pay" element={<PayPage />} />
            <Route path="/wallet/onramp" element={<OnrampPage />} />
            <Route
              path="/wallet/upgrade-to-smart"
              element={<UpgradeToSmartAccountPage />}
            />
            <Route path="/wallet/link-email" element={<EmailToAccountPage />} />
            <Route path="/wallet/auth" element={<AuthPage />} />
            <Route path="*" element={<Navigate to="/wallet/auth" replace />} />
          </Routes>
        </div>
      </main>

      <footer style={styles.footer}>
        <div style={styles.footerInner}>
          <span style={styles.footerText}>
            {window.isFlutterApp
              ? "You can close this screen once the wallet is connected."
              : "Use the navigation routes to test pages."}
          </span>
        </div>
      </footer>
    </div>
  );
}

/** ---------- UI helpers (UI-only; no data layer changes) ---------- */

function truncateMiddle(value: string, left = 6, right = 4) {
  if (value.length <= left + right + 3) return value;
  return `${value.slice(0, left)}…${value.slice(-right)}`;
}

function SectionCard({
  title,
  subtitle,
  children,
  right,
}: {
  title: string;
  subtitle?: string;
  children: React.ReactNode;
  right?: React.ReactNode;
}) {
  return (
    <section style={styles.card}>
      <div style={styles.cardHeader}>
        <div>
          <div style={styles.cardTitle}>{title}</div>
          {subtitle ? <div style={styles.cardSubtitle}>{subtitle}</div> : null}
        </div>
        {right ? <div>{right}</div> : null}
      </div>
      <div style={styles.hr} />
      <div style={styles.cardBody}>{children}</div>
    </section>
  );
}

// function KeyValueRow({ k, v }: { k: string; v: React.ReactNode }) {
//   return (
//     <div style={styles.kvRow}>
//       <div style={styles.kvKey}>{k}</div>
//       <div style={styles.kvValue}>{v}</div>
//     </div>
//   );
// }

// Page Components
function BalancePage() {
  const { currentUser } = useCurrentUser();

  return (
    <div style={styles.stack}>
      <SectionCard
        title="Balance"
        subtitle="View your wallet balance and account details."
        right={
          currentUser?.evmSmartAccounts?.[0] ? (
            <span
              style={styles.badgeOk}
              title={currentUser?.evmSmartAccounts?.[0]}
            >
              {truncateMiddle(currentUser?.evmSmartAccounts?.[0] as string)}
            </span>
          ) : (
            <span style={styles.badgeWarn}>No wallet yet</span>
          )
        }
      >
        <Balance />

        <div style={{ height: 16 }} />

        <div style={styles.grid2}>
          <div style={styles.miniCard}>
            <div style={styles.miniTitle}>Wallet address</div>
            <div style={styles.miniValue}>
              {currentUser?.evmSmartAccounts?.[0]
                ? truncateMiddle(currentUser?.evmSmartAccounts?.[0] as string)
                : "—"}
            </div>
          </div>

          <div style={styles.miniCard}>
            <div style={styles.miniTitle}>Auth methods</div>
            <div style={styles.miniValue}>
              {currentUser ? "Available" : "—"}
            </div>
          </div>
        </div>

        <div style={{ height: 16 }} />
        <LinkEmail />
      </SectionCard>
    </div>
  );
}

function PayPage() {
  const { currentUser } = useCurrentUser();

  return (
    <div style={styles.stack}>
      <SectionCard
        title="Send payment"
        subtitle="Create and send a payment."
        right={
          currentUser?.evmSmartAccounts?.[0] ? (
            <span
              style={styles.badgeOk}
              title={currentUser?.evmSmartAccounts?.[0]}
            >
              {truncateMiddle(currentUser?.evmSmartAccounts?.[0] as string)}
            </span>
          ) : (
            <span style={styles.badgeWarn}>No wallet</span>
          )
        }
      >
        <EURCPayment />
      </SectionCard>
    </div>
  );
}

function OnrampPage() {
  const { currentUser } = useCurrentUser();

  return (
    <div style={styles.stack}>
      <SectionCard
        title="Add funds"
        subtitle="Onramp to your wallet."
        right={
          currentUser?.evmSmartAccounts?.[0] ? (
            <span
              style={styles.badgeOk}
              title={currentUser?.evmSmartAccounts?.[0]}
            >
              {truncateMiddle(currentUser?.evmSmartAccounts?.[0] as string)}
            </span>
          ) : (
            <span style={styles.badgeWarn}>No wallet</span>
          )
        }
      >
        <Onramp />
      </SectionCard>
    </div>
  );
}

function UpgradeToSmartAccountPage() {
  const { currentUser } = useCurrentUser();

  return (
    <div style={styles.stack}>
      <SectionCard
        title="Smart account"
        subtitle="Upgrade to a smart account for better UX."
        right={
          currentUser?.evmSmartAccounts?.[0] ? (
            <span
              style={styles.badgeOk}
              title={currentUser?.evmSmartAccounts?.[0]}
            >
              {truncateMiddle(currentUser?.evmSmartAccounts?.[0] as string)}
            </span>
          ) : (
            <span style={styles.badgeWarn}>No wallet</span>
          )
        }
      >
        <UpgradeToSmartAccount />
      </SectionCard>
    </div>
  );
}

function EmailToAccountPage() {
  const { currentUser } = useCurrentUser();

  return (
    <div style={styles.stack}>
      <SectionCard
        title="Link email"
        subtitle="Link an email authentication method."
        right={
          currentUser?.evmSmartAccounts?.[0] ? (
            <span
              style={styles.badgeOk}
              title={currentUser?.evmSmartAccounts?.[0]}
            >
              {truncateMiddle(currentUser?.evmSmartAccounts?.[0] as string)}
            </span>
          ) : (
            <span style={styles.badgeWarn}>No wallet</span>
          )
        }
      >
        <LinkEmail />
      </SectionCard>
    </div>
  );
}

function AuthPage() {
  const { currentUser } = useCurrentUser();

  if (currentUser) {
    return (
      <div style={styles.stack}>
        <SectionCard
          title="Wallet connected"
          subtitle="Redirecting to balance…"
          right={
            currentUser?.evmSmartAccounts?.[0] ? (
              <span
                style={styles.badgeOk}
                title={currentUser?.evmSmartAccounts?.[0]}
              >
                {truncateMiddle(currentUser?.evmSmartAccounts?.[0] as string)}
              </span>
            ) : null
          }
        >
          <div style={styles.muted}>
            You’re signed in. Taking you to the balance page.
          </div>
        </SectionCard>
        <Navigate to="/wallet/balance" replace />
      </div>
    );
  }

  return (
    <div style={styles.stack}>
      <SectionCard
        title="Sign in"
        subtitle="Complete authentication in the embedded wallet flow."
      >
        <div style={styles.muted}>
          If you opened this inside the SlickBills app, return to the app when
          the wallet is connected.
        </div>

        <div style={{ height: 16 }} />

        <div style={styles.notice}>
          <div style={styles.noticeTitle}>Waiting for sign-in…</div>
          <div style={styles.noticeBody}>
            This page will update automatically once authentication completes.
          </div>
        </div>
      </SectionCard>
    </div>
  );
}

/** ---------- Inline styles (kept here to avoid touching CSS) ---------- */
const styles: Record<string, React.CSSProperties> = {
  page: {
    minHeight: "100dvh",
    background: "linear-gradient(180deg, #0b1220 0%, #070b14 100%)",
    color: "#e5e7eb",
    display: "flex",
    flexDirection: "column",
  },
  header: {
    position: "sticky",
    top: 0,
    zIndex: 10,
    backdropFilter: "blur(10px)",
    backgroundColor: "rgba(7, 11, 20, 0.72)",
    borderBottom: "1px solid rgba(255,255,255,0.08)",
  },
  headerInner: {
    maxWidth: 980,
    margin: "0 auto",
    padding: "16px 16px",
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    gap: 12,
  },
  brandRow: { display: "flex", alignItems: "center", gap: 12 },
  logo: {
    width: 36,
    height: 36,
    borderRadius: 10,
    objectFit: "contain",
    background: "rgba(255,255,255,0.06)",
    border: "1px solid rgba(255,255,255,0.08)",
  },
  logoMark: {
    width: 36,
    height: 36,
    borderRadius: 10,
    background:
      "linear-gradient(135deg, rgba(59,130,246,0.85), rgba(168,85,247,0.85))",
    border: "1px solid rgba(255,255,255,0.12)",
  },
  headerTitle: { fontSize: 16, fontWeight: 700, lineHeight: 1.1 },
  headerSubtitle: { fontSize: 12, opacity: 0.75, marginTop: 2 },
  statusPill: {
    display: "inline-flex",
    alignItems: "center",
    gap: 8,
    padding: "8px 10px",
    borderRadius: 999,
    border: "1px solid rgba(255,255,255,0.10)",
    background: "rgba(255,255,255,0.06)",
    whiteSpace: "nowrap",
  },
  statusDot: { width: 8, height: 8, borderRadius: 999 },
  statusText: { fontSize: 12, opacity: 0.9 },

  main: { flex: 1, padding: "22px 0" },
  container: { maxWidth: 980, padding: "0 16px", margin: "0 auto" },

  stack: { display: "flex", flexDirection: "column", gap: 16 },

  card: {
    borderRadius: 16,
    border: "1px solid rgba(255,255,255,0.10)",
    background: "rgba(255,255,255,0.06)",
    boxShadow: "0 10px 30px rgba(0,0,0,0.35)",
  },
  cardHeader: {
    padding: "16px 16px 12px",
    display: "flex",
    alignItems: "flex-start",
    justifyContent: "space-between",
    gap: 12,
  },
  cardTitle: { fontSize: 16, fontWeight: 700 },
  cardSubtitle: { fontSize: 12, opacity: 0.75, marginTop: 4 },
  cardBody: { padding: 16 },

  hr: { height: 1, background: "rgba(255,255,255,0.10)" },

  muted: { fontSize: 13, opacity: 0.8, lineHeight: 1.5 },

  badgeOk: {
    display: "inline-flex",
    alignItems: "center",
    padding: "6px 10px",
    borderRadius: 999,
    border: "1px solid rgba(34,197,94,0.35)",
    background: "rgba(34,197,94,0.10)",
    color: "#bbf7d0",
    fontSize: 12,
    fontWeight: 600,
  },
  badgeWarn: {
    display: "inline-flex",
    alignItems: "center",
    padding: "6px 10px",
    borderRadius: 999,
    border: "1px solid rgba(245,158,11,0.35)",
    background: "rgba(245,158,11,0.10)",
    color: "#fde68a",
    fontSize: 12,
    fontWeight: 600,
  },

  grid2: {
    display: "grid",
    gridTemplateColumns: "repeat(2, minmax(0, 1fr))",
    gap: 12,
  },
  miniCard: {
    borderRadius: 14,
    border: "1px solid rgba(255,255,255,0.10)",
    background: "rgba(0,0,0,0.18)",
    padding: 12,
  },
  miniTitle: { fontSize: 12, opacity: 0.75 },
  miniValue: { marginTop: 6, fontSize: 13, fontWeight: 700 },

  notice: {
    borderRadius: 14,
    border: "1px solid rgba(59,130,246,0.25)",
    background: "rgba(59,130,246,0.10)",
    padding: 12,
  },
  noticeTitle: { fontSize: 13, fontWeight: 700 },
  noticeBody: { fontSize: 12, opacity: 0.85, marginTop: 4 },

  kvRow: {
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    gap: 12,
    padding: "10px 0",
    borderBottom: "1px solid rgba(255,255,255,0.08)",
  },
  kvKey: { fontSize: 12, opacity: 0.75 },
  kvValue: { fontSize: 12, fontWeight: 700 },

  footer: {
    borderTop: "1px solid rgba(255,255,255,0.08)",
    background: "rgba(7, 11, 20, 0.55)",
  },
  footerInner: {
    maxWidth: 980,
    margin: "0 auto",
    padding: "14px 16px",
  },
  footerText: { fontSize: 12, opacity: 0.78 },

  centerScreen: {
    minHeight: "100dvh",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    padding: 16,
    background: "linear-gradient(180deg, #0b1220 0%, #070b14 100%)",
    color: "#e5e7eb",
  },

  brandTitle: { fontWeight: 800, letterSpacing: 0.2 },
  brandSubtitle: { fontSize: 12, opacity: 0.75, marginTop: 2 },
};

export default App;
