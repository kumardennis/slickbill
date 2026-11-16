import { isDev } from "./config";

/** Staging only — these accounts use Web3Auth; everyone else on staging uses Privy. */
export const WEB3AUTH_WALLET_EMAILS = new Set([
  "kumardaisy18@gmail.com",
  "denniskumar299@gmail.com",
  "kumaringrid@gmail.com",
  "johnny.lever2999@gmail.com",
]);

const EMAIL_SESSION_KEY = "sb_wallet_auth_email";

function normalizeEmail(raw: string | null | undefined): string | null {
  const email = (raw ?? "").trim().toLowerCase();
  return email.includes("@") ? email : null;
}

/** Persist email from the open URL so Web3Auth redirect returns still match. */
export function rememberWalletAuthEmailFromUrl(): string | null {
  if (typeof window === "undefined") return null;
  const params = new URLSearchParams(window.location.search);
  const fromQuery = normalizeEmail(params.get("email"));
  if (fromQuery) {
    window.sessionStorage.setItem(EMAIL_SESSION_KEY, fromQuery);
    return fromQuery;
  }
  return normalizeEmail(window.sessionStorage.getItem(EMAIL_SESSION_KEY));
}

/**
 * Production: Privy always.
 * Staging: Web3Auth only for allowlisted emails; everyone else Privy.
 */
export function shouldUseWeb3AuthWalletAuth(): boolean {
  if (!isDev) return false;
  const email = rememberWalletAuthEmailFromUrl();
  return email != null && WEB3AUTH_WALLET_EMAILS.has(email);
}
