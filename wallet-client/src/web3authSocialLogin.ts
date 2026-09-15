/**
 * Facebook custom connection id is optional. Staging uses
 * `slickbills-test` (Web3Auth dashboard). Mainnet without a Pro plan
 * has no custom connections — omit the id and use default Facebook.
 *
 * Never put the Facebook App Secret here or in any VITE_ variable.
 */
function facebookAuthConnectionId(): string {
  const fromEnv =
    import.meta.env.VITE_WEB3AUTH_FACEBOOK_AUTH_CONNECTION_ID?.trim() ?? "";
  if (fromEnv) return fromEnv;
  const appEnv = (import.meta.env.VITE_APP_ENV ?? "").toLowerCase();
  if (appEnv === "prod" || appEnv === "production") return "";
  return "slickbills-test";
}

export function web3AuthSocialLoginMethods() {
  const connectionId = facebookAuthConnectionId();

  return {
    google: {
      name: "Google",
      showOnModal: true,
    },
    facebook: {
      name: "Facebook",
      showOnModal: true,
      ...(connectionId ? { authConnectionId: connectionId } : {}),
    },
  };
}
