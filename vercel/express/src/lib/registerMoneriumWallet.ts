import { addAddressesToAlchemyWebhook } from "./alchemyAddresses.js";
import {
  loadMoneriumToken,
  persistMoneriumToken,
  updateMoneriumTokenWallet,
  type StoredMoneriumToken,
} from "./moneriumTokens.js";
import { getSupabaseAdmin } from "./supabaseAdmin.js";

const normalizeWallet = (value?: string | null): string | null => {
  if (!value || typeof value !== "string") return null;
  const match = value.trim().match(/0x[a-fA-F0-9]{40}/);
  return match ? match[0].toLowerCase() : null;
};

const lookupWalletFromUsers = async (
  privateUserId: string,
): Promise<string | null> => {
  const supabase = getSupabaseAdmin();
  if (!supabase) return null;

  const id = Number(privateUserId);
  if (!Number.isFinite(id) || id <= 0) return null;

  const { data: privateUser } = await (supabase.from("private_users") as any)
    .select("userId")
    .eq("id", id)
    .maybeSingle();
  const appUserId = Number(privateUser?.userId);
  if (!Number.isFinite(appUserId) || appUserId <= 0) return null;

  const { data: user } = await (supabase.from("users") as any)
    .select("cdpWalletId, metamask_wallet_address")
    .eq("id", appUserId)
    .maybeSingle();

  return (
    normalizeWallet(user?.metamask_wallet_address) ??
    normalizeWallet(user?.cdpWalletId)
  );
};

/**
 * Persist wallet on monerium_tokens and add it to the Alchemy Address Activity
 * webhook so mints/burns on this account are attributed.
 */
export const registerMoneriumWallet = async (params: {
  privateUserId: string;
  walletAddress?: string | null;
  token?: StoredMoneriumToken | null;
}): Promise<{
  ok: boolean;
  wallet?: string;
  alchemy?: { ok: boolean; detail?: string; skipped?: boolean };
  detail?: string;
}> => {
  const userId = params.privateUserId.trim();
  if (!userId) {
    return { ok: false, detail: "missing_user" };
  }

  const wallet =
    normalizeWallet(params.walletAddress) ??
    (await lookupWalletFromUsers(userId));

  if (!wallet) {
    return { ok: false, detail: "no_wallet" };
  }

  await updateMoneriumTokenWallet(userId, wallet);

  const token =
    params.token ??
    (await loadMoneriumToken(userId));
  if (token) {
    await persistMoneriumToken(userId, token, wallet);
  }

  const alchemy = await addAddressesToAlchemyWebhook([wallet]);
  console.log("ℹ️ Registered Monerium wallet for Alchemy", {
    privateUserId: userId,
    wallet,
    alchemy,
    persistedToken: Boolean(token),
  });

  return { ok: true, wallet, alchemy };
};
