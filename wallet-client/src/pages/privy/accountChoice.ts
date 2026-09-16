const LAST_USED_KEY = "sb_privy_last_used";
export const LOGIN_STARTED_KEY = "sb_privy_login_started";

export type LastUsedAccount = {
  email?: string;
  name?: string;
  address?: string;
};

export function readLastUsedAccount(): LastUsedAccount | null {
  try {
    const raw = window.localStorage.getItem(LAST_USED_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as LastUsedAccount;
    if (!parsed.email && !parsed.name && !parsed.address) return null;
    return parsed;
  } catch {
    return null;
  }
}

export function writeLastUsedAccount(partial: LastUsedAccount): void {
  try {
    const prev = readLastUsedAccount() ?? {};
    const next: LastUsedAccount = { ...prev };
    if (partial.email) next.email = partial.email;
    if (partial.name) next.name = partial.name;
    if (partial.address) next.address = partial.address;
    window.localStorage.setItem(LAST_USED_KEY, JSON.stringify(next));
  } catch {
    // Ignore storage errors.
  }
}

export function loginWasStarted(): boolean {
  try {
    return window.sessionStorage.getItem(LOGIN_STARTED_KEY) === "1";
  } catch {
    return false;
  }
}

export function markLoginStarted(): void {
  try {
    window.sessionStorage.setItem(LOGIN_STARTED_KEY, "1");
  } catch {
    // Ignore storage errors.
  }
}

export function clearLoginStarted(): void {
  try {
    window.sessionStorage.removeItem(LOGIN_STARTED_KEY);
  } catch {
    // Ignore storage errors.
  }
}

export function shortenAddress(address: string): string {
  if (address.length < 12) return address;
  return `${address.slice(0, 6)}…${address.slice(-4)}`;
}
