/**
 * Public Web3Auth Facebook connection id from the dashboard (Social
 * Connections → Facebook → custom connection). This is an identifier, not a
 * secret — same class as the Web3Auth client id.
 *
 * Never put the Facebook App Secret here or in any VITE_ variable. The secret
 * stays only in the Web3Auth dashboard.
 */
const FACEBOOK_AUTH_CONNECTION_ID = "slickbills-test";

export function web3AuthSocialLoginMethods() {
  const facebookAuthConnectionId = FACEBOOK_AUTH_CONNECTION_ID.trim();

  return {
    google: {
      name: "Google",
      showOnModal: true,
    },
    facebook: {
      name: "Facebook",
      showOnModal: true,
      ...(facebookAuthConnectionId
        ? { authConnectionId: facebookAuthConnectionId }
        : {}),
    },
  };
}
