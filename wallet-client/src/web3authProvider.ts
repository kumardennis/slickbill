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
      "eoaAddress",
      "data",
    ]) {
      if (key in obj) collectAddresses(obj[key], into);
    }
  }
  return into;
}

function connectionEthereumProvider(
  web3Auth: unknown,
  connectResult?: unknown,
): unknown {
  const result = connectResult as {
    ethereumProvider?: unknown;
    request?: unknown;
  } | null;
  if (result?.ethereumProvider) return result.ethereumProvider;
  if (result && typeof result.request === "function") return result;

  const auth = web3Auth as {
    connection?: { ethereumProvider?: unknown } | null;
  };
  return auth.connection?.ethereumProvider ?? null;
}

/** v11: EOA lives on `connection.ethereumProvider`, not `web3auth.provider`. */
export function eip1193Provider(
  web3Auth: unknown,
  connectResult?: unknown,
): unknown {
  return connectionEthereumProvider(web3Auth, connectResult);
}

export function isWeb3AuthConnected(web3Auth: unknown): boolean {
  const auth = web3Auth as {
    connected?: boolean;
    connection?: unknown;
    status?: string;
    primaryConnectorName?: string | null;
  };
  return Boolean(
    auth.connected ||
      auth.connection ||
      auth.primaryConnectorName ||
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

async function linkedEoaAddresses(web3Auth: unknown): Promise<string[]> {
  const auth = web3Auth as {
    getLinkedAccounts?: () => Promise<unknown>;
    getConnectedAccountsWithProviders?: () => unknown;
  };
  const found: string[] = [];
  if (typeof auth.getLinkedAccounts === "function") {
    try {
      collectAddresses(await auth.getLinkedAccounts(), found);
    } catch {
      // Linked accounts may be unavailable before the session hydrates.
    }
  }
  if (typeof auth.getConnectedAccountsWithProviders === "function") {
    try {
      collectAddresses(auth.getConnectedAccountsWithProviders(), found);
    } catch {
      // Ignore snapshot failures.
    }
  }
  return found;
}

export async function resolveWalletAddress(
  provider: unknown,
  expectedAddress?: string | null,
  extraAddresses: string[] = [],
): Promise<string> {
  const expected = expectedAddress?.trim() || null;
  const wrapper = provider as RpcProvider | null;
  const candidates: string[] = [...extraAddresses];
  if (wrapper) {
    candidates.push(
      ...collectAddresses([
        wrapper.accounts,
        wrapper.selectedAddress,
        wrapper.address,
      ]),
    );
    candidates.push(...(await requestAccounts(wrapper, "eth_accounts")));
    if (candidates.length === 0) {
      candidates.push(...(await requestAccounts(wrapper, "eth_requestAccounts")));
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

function safeJson(value: unknown): string {
  try {
    return JSON.stringify(value);
  } catch {
    return String(value);
  }
}

export async function inspectWeb3AuthSession(
  web3Auth: unknown,
  connectResult?: unknown,
): Promise<string[]> {
  const auth = web3Auth as {
    connected?: boolean;
    status?: string;
    primaryConnectorName?: string | null;
    currentChainId?: string | null;
    connection?: {
      ethereumProvider?: unknown;
      connectorName?: string;
      connectorNamespace?: string;
    } | null;
    getUserInfo?: () => Promise<Record<string, unknown>>;
  };
  const lines: string[] = [];
  lines.push(`connected=${String(auth.connected)} status=${auth.status ?? "?"}`);
  lines.push(
    `connector=${auth.primaryConnectorName ?? "none"} chain=${auth.currentChainId ?? "none"}`,
  );
  const connection = auth.connection ?? null;
  const result = connectResult as {
    ethereumProvider?: unknown;
    connectorName?: string;
  } | null;
  const ethProvider =
    result?.ethereumProvider ?? connection?.ethereumProvider ?? null;
  lines.push(
    `connection=${connection ? "yes" : "no"} resultConnector=${result?.connectorName ?? "none"}`,
  );
  lines.push(
    `ethereumProvider=${ethProvider ? "yes" : "no"} hasRequest=${
      typeof (ethProvider as { request?: unknown } | null)?.request ===
      "function"
        ? "yes"
        : "no"
    }`,
  );

  const provider = ethProvider as RpcProvider | null;
  if (provider && typeof provider.request === "function") {
    for (const method of ["eth_accounts", "eth_chainId"] as const) {
      try {
        const raw = await provider.request({ method });
        lines.push(`${method}=${safeJson(raw)}`);
      } catch (err) {
        lines.push(
          `${method} error=${err instanceof Error ? err.message : String(err)}`,
        );
      }
    }
  }

  const linked = await linkedEoaAddresses(web3Auth);
  lines.push(`linkedEoas=${linked.length ? linked.join(",") : "none"}`);

  if (typeof auth.getUserInfo === "function") {
    try {
      const info = await auth.getUserInfo();
      lines.push(
        `user=${String(info.email ?? info.name ?? info.verifierId ?? "none")} type=${String(info.typeOfLogin ?? info.authConnection ?? "?")}`,
      );
    } catch (err) {
      lines.push(
        `userInfo error=${err instanceof Error ? err.message : String(err)}`,
      );
    }
  }

  return lines;
}

export async function waitForWalletAddress(
  web3Auth: unknown,
  connectResult?: unknown,
  expectedAddress?: string | null,
  attempts = 20,
): Promise<{ provider: unknown; address: string }> {
  let lastError: Error | null = null;
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    const provider = eip1193Provider(web3Auth, connectResult);
    const linked = await linkedEoaAddresses(web3Auth);
    if (provider) {
      try {
        const address = await resolveWalletAddress(
          provider,
          expectedAddress,
          linked,
        );
        return { provider, address };
      } catch (err) {
        lastError = err instanceof Error ? err : new Error(String(err));
      }
    } else if (linked[0]) {
      lastError = new Error(
        "No wallet address returned by authenticated provider",
      );
    }
    await delay(250);
  }
  throw (
    lastError ??
    new Error("No wallet address returned by authenticated provider")
  );
}
