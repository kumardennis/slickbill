import { PrivyProvider } from "@privy-io/react-auth";
import type { ReactNode } from "react";
import { PrivyAuth } from "./PrivyAuth";
import { privyAppId, privyConfig } from "../../privyConfig";
import { sb } from "../../theme";
import logo from "../../assets/logo_icon.png";

function PrivySetupMissing() {
  return (
    <div
      style={{
        minHeight: "100vh",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        padding: 20,
        fontFamily: "Inter, system-ui, sans-serif",
        background:
          "linear-gradient(180deg, #F4FAFB 0%, #EEF6F8 48%, #F7FBFC 100%)",
        color: sb.onSurface,
      }}
    >
      <div
        style={{
          maxWidth: 420,
          width: "100%",
          borderRadius: 16,
          border: `1px solid ${sb.outlineVariant}`,
          background: sb.surfaceLowest,
          padding: 24,
        }}
      >
        <img
          src={logo}
          alt="SlickBills"
          width={32}
          height={32}
          style={{ borderRadius: 8 }}
        />
        <h1 style={{ fontSize: 22, margin: "16px 0 8px" }}>
          Privy is not configured
        </h1>
        <p style={{ margin: 0, color: sb.onSurfaceVariant, lineHeight: 1.5 }}>
          Create an app at dashboard.privy.io, enable Google, allowlist this
          origin, then set VITE_PRIVY_APP_ID on the wallet-client build.
        </p>
      </div>
    </div>
  );
}

export function PrivyRoot({ children }: { children: ReactNode }) {
  if (!privyAppId) {
    return <PrivySetupMissing />;
  }

  return (
    <PrivyProvider
      appId={privyAppId}
      config={{
        ...privyConfig,
        customOAuthRedirectUrl: window.location.href,
      }}
    >
      {children}
    </PrivyProvider>
  );
}

export function PrivyAuthRoot() {
  return (
    <PrivyRoot>
      <PrivyAuth />
    </PrivyRoot>
  );
}
