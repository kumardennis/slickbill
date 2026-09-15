const HEX_ADDRESS = /^0x[a-fA-F0-9]{40}$/;

type RpcProvider = {
  request?: (args: { method: string; params?: unknown }) => Promise<unknown>;
  accounts?: unknown;
  selectedAddress?: unknown;
  address?: unknown;
  provider?: unknown;
  ethereumProvider?: unknown;
};

function isHexAddress(value: unknown): value is string {
  return typeof value === "string" && HEX_ADDRESS.test(value.trim());
}

function collectAddresses(raw: unknown, into: string[] = []): string[] {
  if (isHexAddress(raw)) {
    into.push(raw.trim());
    return into;
  }
  if (Array.isArray(raw)) {
    for (const item of raw) collectAddresses(item, into);
    return into;
  }
  if (raw && typeof raw === "object") {
    const obj = raw as Record<string, unknown>;
    for (const key of [
      "result",
      "accounts",
      "address",
      "selectedAddress",
      "data",
    ]) {
      if (key in obj) collectAddresses(obj[key], into);
    }
  }
  return into;
}

function pushProvider(into: RpcProvider[], seen: Set<unknown>, value: unknown) {
  if (!value || typeof value !== "object" || seen.has(value)) return;
  seen.add(value);
  into.push(value as RpcProvider);
  const obj = value as RpcProvider;
  pushProvider(into, seen, obj.ethereumProvider);
  pushProvider(into, seen, obj.provider);
}

/** Web3Auth v10 `connect()` may return a Connection, not an EIP-1193 provider. */
export function eip1193Provider(
  web3Auth: unknown,
  connectResult?: unknown,
): unknown {
  const wrappers: RpcProvider[] = [];
  const seen = new Set<unknown>();
  pushProvider(wrappers, seen, connectResult);

  const auth = web3Auth as {
    provider?: unknown;
    connection?: { ethereumProvider?: unknown; provider?: unknown };
    getProvider?: () => unknown;
  };
  pushProvider(wrappers, seen, auth.connection);
  pushProvider(wrappers, seen, auth.connection?.ethereumProvider);
  pushProvider(wrappers, seen, auth.provider);
  if (typeof auth.getProvider === "function") {
    try {
      pushProvider(wrappers, seen, auth.getProvider());
    } catch {
      // Ignore getters that throw before the session is ready.
    }
  }

  const withRequest = wrappers.find(
    (wrapper) => typeof wrapper.request === "function",
  );
  return withRequest ?? wrappers[0] ?? null;
}

export function isWeb3AuthConnected(web3Auth: unknown): boolean {
  const auth = web3Auth as {
    connected?: boolean;
    status?: string;
    connectedConnectorName?: string | null;
  };
  return Boolean(
    auth.connected ||
      auth.connectedConnectorName ||
      auth.status === "connected" ||
      auth.status === "authorized",
  );
}

async function requestAccounts(
  provider: RpcProvider | null | undefined,
  method: string,
): Promise<string[]> {
  if (!provider || typeof provider.request !== "function") return [];
  try {
    return collectAddresses(await provider.request({ method }));
  } catch {
    return [];
  }
}

export async function resolveWalletAddress(
  provider: unknown,
  expectedAddress?: string | null,
): Promise<string> {
  const expected = expectedAddress?.trim() || null;
  const wrappers: RpcProvider[] = [];
  pushProvider(wrappers, new Set<unknown>(), provider);

  const candidates: string[] = [];
  for (const wrapper of wrappers) {
    candidates.push(
      ...collectAddresses([
        wrapper.accounts,
        wrapper.selectedAddress,
        wrapper.address,
      ]),
    );
    candidates.push(...(await requestAccounts(wrapper, "eth_accounts")));
  }

  if (candidates.length === 0) {
    for (const wrapper of wrappers) {
      candidates.push(
        ...(await requestAccounts(wrapper, "eth_requestAccounts")),
      );
    }
  }

  const unique = [...new Set(candidates.map((value) => value.toLowerCase()))];
  if (expected && isHexAddress(expected)) {
    const match = unique.find((value) => value === expected.toLowerCase());
    if (match) {
      return (
        candidates.find((value) => value.toLowerCase() === match) ?? expected
      );
    }
  }

  const first = candidates[0];
  if (first) return first;

  throw new Error("No wallet address returned by authenticated provider");
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => {
    window.setTimeout(resolve, ms);
  });
}

export async function waitForWalletAddress(
  web3Auth: unknown,
  connectResult?: unknown,
  expectedAddress?: string | null,
  attempts = 12,
): Promise<{ provider: unknown; address: string }> {
  let lastError: Error | null = null;
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    const provider = eip1193Provider(web3Auth, connectResult);
    if (provider) {
      try {
        const address = await resolveWalletAddress(provider, expectedAddress);
        return { provider, address };
      } catch (err) {
        lastError = err instanceof Error ? err : new Error(String(err));
      }
    }
    await delay(250);
  }
  throw (
    lastError ??
    new Error("No wallet address returned by authenticated provider")
  );
}
