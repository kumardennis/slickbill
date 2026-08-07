import crypto from "node:crypto";

export const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

export type WalletActivityTransfer = {
  txHash: string;
  from: string;
  to: string;
  kind: "mint" | "burn" | "transfer";
  walletAddress: string;
  contractAddress?: string;
  value?: string;
  category?: string;
  asset?: string;
};

const normalizeAddress = (value?: string | null): string | null => {
  if (!value || typeof value !== "string") return null;
  const match = value.trim().match(/0x[a-fA-F0-9]{40}/);
  return match ? match[0].toLowerCase() : null;
};

const normalizeTxHash = (value?: string | null): string | null => {
  if (!value || typeof value !== "string") return null;
  const trimmed = value.trim().toLowerCase();
  if (!/^0x[a-f0-9]{64}$/.test(trimmed)) return null;
  return trimmed;
};

export const verifyAlchemySignature = (params: {
  rawBody: string | Buffer;
  signature: string | undefined;
  signingKey: string;
}): boolean => {
  const { rawBody, signature, signingKey } = params;
  if (!signature || !signingKey) return false;

  const body =
    typeof rawBody === "string" ? rawBody : rawBody.toString("utf8");
  const digest = crypto
    .createHmac("sha256", signingKey)
    .update(body, "utf8")
    .digest("hex");

  try {
    const a = Buffer.from(digest, "utf8");
    const b = Buffer.from(signature.trim(), "utf8");
    if (a.length !== b.length) return false;
    return crypto.timingSafeEqual(new Uint8Array(a), new Uint8Array(b));
  } catch {
    return false;
  }
};

const pushActivity = (
  out: WalletActivityTransfer[],
  params: {
    txHash?: string | null;
    from?: string | null;
    to?: string | null;
    contractAddress?: string | null;
    value?: string | null;
    eureAddress?: string | null;
    category?: string | null;
    asset?: string | null;
    /** If true, only keep mint/burn. If false, keep any transfer involving a non-zero party. */
    mintBurnOnly?: boolean;
  },
) => {
  const txHash = normalizeTxHash(params.txHash);
  const from = normalizeAddress(params.from);
  const to = normalizeAddress(params.to);
  if (!txHash || !from || !to) return;

  const isMint = from === ZERO_ADDRESS;
  const isBurn = to === ZERO_ADDRESS;
  if (params.mintBurnOnly && !isMint && !isBurn) return;

  const contract = normalizeAddress(params.contractAddress);
  const eure = normalizeAddress(params.eureAddress ?? null);
  // Only apply EURe filter when we have a contract address to compare.
  if (eure && contract && contract !== eure) return;

  const kind: WalletActivityTransfer["kind"] = isMint
    ? "mint"
    : isBurn
      ? "burn"
      : "transfer";

  const candidates = [from, to].filter(
    (a) => a && a !== ZERO_ADDRESS,
  ) as string[];

  for (const walletAddress of candidates) {
    out.push({
      txHash,
      from,
      to,
      kind,
      walletAddress,
      contractAddress: contract ?? undefined,
      value: params.value ?? undefined,
      category: params.category ?? undefined,
      asset: params.asset ?? undefined,
    });
  }
};

export const summarizeAlchemyPayload = (payload: unknown) => {
  if (!payload || typeof payload !== "object") {
    return { activityCount: 0, sample: null as unknown };
  }
  const root = payload as Record<string, any>;
  const event = root.event && typeof root.event === "object" ? root.event : root;
  const activity = Array.isArray(event.activity)
    ? event.activity
    : Array.isArray(root.activity)
      ? root.activity
      : [];
  const sample = activity[0]
    ? {
        hash: activity[0].hash,
        fromAddress: activity[0].fromAddress,
        toAddress: activity[0].toAddress,
        category: activity[0].category,
        asset: activity[0].asset,
        contract: activity[0].rawContract?.address,
      }
    : null;
  return { activityCount: activity.length, sample };
};

/**
 * Extract wallet activities from Alchemy Address Activity payloads.
 * By default includes mint/burn and normal transfers (needed for reliable notify).
 */
export const extractMintBurnTransfers = (
  payload: unknown,
  eureTokenAddress?: string | null,
  options?: { mintBurnOnly?: boolean },
): WalletActivityTransfer[] => {
  const out: WalletActivityTransfer[] = [];
  const eure = eureTokenAddress ?? null;
  const mintBurnOnly = options?.mintBurnOnly === true;

  if (!payload || typeof payload !== "object") {
    return out;
  }

  const root = payload as Record<string, any>;
  const event = root.event && typeof root.event === "object" ? root.event : root;
  const activity = Array.isArray(event.activity)
    ? event.activity
    : Array.isArray(root.activity)
      ? root.activity
      : [];

  for (const item of activity) {
    if (!item || typeof item !== "object") continue;
    pushActivity(out, {
      txHash: item.hash ?? item.transactionHash ?? item.txHash,
      from: item.fromAddress ?? item.from,
      to: item.toAddress ?? item.to,
      contractAddress: item.rawContract?.address ?? item.contractAddress,
      value:
        item.value != null
          ? String(item.value)
          : item.rawContract?.rawValue != null
            ? String(item.rawContract.rawValue)
            : null,
      eureAddress: eure,
      category: typeof item.category === "string" ? item.category : null,
      asset: typeof item.asset === "string" ? item.asset : null,
      mintBurnOnly,
    });
  }

  const logs = Array.isArray(event.logs)
    ? event.logs
    : Array.isArray(root.logs)
      ? root.logs
      : [];

  for (const log of logs) {
    if (!log || typeof log !== "object") continue;
    const topics: string[] = Array.isArray(log.topics) ? log.topics : [];
    if (
      topics[0]?.toLowerCase() !==
      "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
    ) {
      continue;
    }
    const fromTopic = topics[1];
    const toTopic = topics[2];
    const from =
      typeof fromTopic === "string" && fromTopic.length >= 40
        ? `0x${fromTopic.slice(-40)}`
        : null;
    const to =
      typeof toTopic === "string" && toTopic.length >= 40
        ? `0x${toTopic.slice(-40)}`
        : null;
    pushActivity(out, {
      txHash: log.transactionHash ?? log.txHash ?? log.hash,
      from,
      to,
      contractAddress: log.address,
      value: typeof log.data === "string" ? log.data : null,
      eureAddress: eure,
      mintBurnOnly,
    });
  }

  const seen = new Set<string>();
  return out.filter((t) => {
    const key = `${t.txHash}:${t.walletAddress}:${t.kind}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
};
