import { getSupabaseAdmin } from "./supabaseAdmin.js";

export type StoredMoneriumToken = {
  accessToken: string;
  refreshToken?: string;
  tokenType: string;
  scope?: string;
  expiresAt: number;
  createdAt: number;
  walletAddress?: string | null;
};

type MoneriumTokenRow = {
  privateUserId: string;
  accessToken: string;
  refreshToken: string | null;
  tokenType: string | null;
  scope: string | null;
  expiresAt: string;
  walletAddress: string | null;
  updatedAt: string | null;
};

const normalizeWallet = (value?: string | null) => {
  if (!value || typeof value !== "string") return null;
  const match = value.trim().match(/0x[a-fA-F0-9]{40}/);
  return match ? match[0].toLowerCase() : null;
};

/** Untyped table accessor — monerium_tokens is not in generated Database types yet. */
const tokens = () => {
  const supabase = getSupabaseAdmin();
  if (!supabase) return null;
  return supabase.from("monerium_tokens") as any;
};

export const persistMoneriumToken = async (
  privateUserId: string,
  token: StoredMoneriumToken,
  walletAddress?: string | null,
): Promise<void> => {
  const table = tokens();
  if (!table || !privateUserId.trim()) {
    return;
  }

  const wallet =
    normalizeWallet(walletAddress) ?? normalizeWallet(token.walletAddress);

  // Never write walletAddress: null on upsert — refresh paths would wipe it.
  const row: Record<string, unknown> = {
    privateUserId: privateUserId.trim(),
    accessToken: token.accessToken,
    refreshToken: token.refreshToken ?? null,
    tokenType: token.tokenType || "Bearer",
    scope: token.scope ?? null,
    expiresAt: new Date(token.expiresAt).toISOString(),
    updatedAt: new Date().toISOString(),
  };
  if (wallet) {
    row.walletAddress = wallet;
  }

  const { error } = await table.upsert(row, { onConflict: "privateUserId" });

  if (error) {
    console.error("❌ Failed to persist monerium_tokens", {
      privateUserId,
      message: error.message,
      hasWallet: Boolean(wallet),
    });
  } else {
    console.log("💾 monerium_tokens upserted", {
      privateUserId,
      walletAddress: wallet,
    });
  }
};

export const updateMoneriumTokenWallet = async (
  privateUserId: string,
  walletAddress: string,
): Promise<void> => {
  const table = tokens();
  const wallet = normalizeWallet(walletAddress);
  if (!table || !privateUserId.trim() || !wallet) {
    return;
  }

  const { data, error } = await table
    .update({
      walletAddress: wallet,
      updatedAt: new Date().toISOString(),
    })
    .eq("privateUserId", privateUserId.trim())
    .select("privateUserId");

  if (error) {
    console.error("❌ Failed to update monerium_tokens wallet", {
      privateUserId,
      message: error.message,
    });
    return;
  }

  if (!data || (Array.isArray(data) && data.length === 0)) {
    console.warn(
      "⚠️ monerium_tokens wallet update matched 0 rows; upserting wallet only failed without token row",
      { privateUserId, wallet },
    );
    return;
  }

  console.log("💾 monerium_tokens wallet updated", {
    privateUserId,
    walletAddress: wallet,
  });
};

export const loadMoneriumToken = async (
  privateUserId: string,
): Promise<StoredMoneriumToken | null> => {
  const table = tokens();
  if (!table || !privateUserId.trim()) {
    return null;
  }

  const { data, error } = await table
    .select(
      "accessToken, refreshToken, tokenType, scope, expiresAt, walletAddress",
    )
    .eq("privateUserId", privateUserId.trim())
    .maybeSingle();

  const row = data as MoneriumTokenRow | null;
  if (error || !row?.accessToken) {
    if (error) {
      console.error("❌ Failed to load monerium_tokens", {
        privateUserId,
        message: error.message,
      });
    }
    return null;
  }

  const expiresAtMs = Date.parse(row.expiresAt);
  return {
    accessToken: row.accessToken,
    refreshToken: row.refreshToken ?? undefined,
    tokenType: row.tokenType || "Bearer",
    scope: row.scope ?? undefined,
    expiresAt: Number.isFinite(expiresAtMs)
      ? expiresAtMs
      : Date.now() + 55 * 60 * 1000,
    createdAt: Date.now(),
    walletAddress: row.walletAddress ?? null,
  };
};

export const loadMoneriumTokenByWallet = async (
  walletAddress: string,
): Promise<{ privateUserId: string; token: StoredMoneriumToken } | null> => {
  const table = tokens();
  const wallet = normalizeWallet(walletAddress);
  if (!table || !wallet) {
    return null;
  }

  const { data, error } = await table
    .select(
      "privateUserId, accessToken, refreshToken, tokenType, scope, expiresAt, walletAddress",
    )
    .eq("walletAddress", wallet)
    .maybeSingle();

  const row = data as MoneriumTokenRow | null;
  if (error || !row?.accessToken || !row.privateUserId) {
    if (error) {
      console.error("❌ Failed to load monerium_tokens by wallet", {
        wallet,
        message: error.message,
      });
    }
    return null;
  }

  const expiresAtMs = Date.parse(row.expiresAt);
  return {
    privateUserId: row.privateUserId,
    token: {
      accessToken: row.accessToken,
      refreshToken: row.refreshToken ?? undefined,
      tokenType: row.tokenType || "Bearer",
      scope: row.scope ?? undefined,
      expiresAt: Number.isFinite(expiresAtMs)
        ? expiresAtMs
        : Date.now() + 55 * 60 * 1000,
      createdAt: Date.now(),
      walletAddress: row.walletAddress ?? null,
    },
  };
};

export const getMoneriumTokenStatus = async (privateUserId: string) => {
  const table = tokens();
  if (!table) {
    return {
      configured: false,
      persisted: false,
      reason: "SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY missing",
    };
  }

  const { data, error } = await table
    .select("privateUserId, expiresAt, walletAddress, updatedAt, refreshToken")
    .eq("privateUserId", privateUserId.trim())
    .maybeSingle();

  if (error) {
    return {
      configured: true,
      persisted: false,
      reason: error.message,
    };
  }

  const row = data as MoneriumTokenRow | null;
  if (!row) {
    return {
      configured: true,
      persisted: false,
      reason: "no row",
    };
  }

  const expiresAtMs = Date.parse(row.expiresAt);
  return {
    configured: true,
    persisted: true,
    privateUserId: row.privateUserId,
    walletAddress: row.walletAddress,
    expiresAt: expiresAtMs,
    expiresAtIso: row.expiresAt,
    hasRefreshToken: Boolean(row.refreshToken),
    updatedAt: row.updatedAt,
    expired: Number.isFinite(expiresAtMs) ? expiresAtMs <= Date.now() : null,
  };
};
