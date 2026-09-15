/** Web3Auth v10 `connect()` returns a Connection, not an EIP-1193 provider. */
export function eip1193Provider(
  web3Auth: unknown,
  connectResult?: unknown,
): unknown {
  const result = connectResult as {
    request?: unknown;
    ethereumProvider?: unknown;
    provider?: unknown;
  } | null;
  if (result && typeof result.request === "function") return result;
  if (result?.ethereumProvider) return result.ethereumProvider;
  if (result?.provider && typeof (result.provider as { request?: unknown }).request === "function") {
    return result.provider;
  }

  const auth = web3Auth as {
    provider?: unknown;
    connection?: { ethereumProvider?: unknown };
  };
  if (auth.connection?.ethereumProvider) return auth.connection.ethereumProvider;
  if (auth.provider) return auth.provider;
  return null;
}

export function isWeb3AuthConnected(web3Auth: unknown): boolean {
  return Boolean((web3Auth as { connected?: boolean }).connected);
}
