type SendFcmPushArgs = {
  token: string;
  title: string;
  body: string;
  data?: Record<string, unknown>;
};

const GOOGLE_OAUTH_TOKEN_URL = "https://oauth2.googleapis.com/token";
const GOOGLE_FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";

function getRequiredEnv(name: string): string {
  const value = Deno.env.get(name) ?? "";
  if (!value) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return value;
}

function toBase64Url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

async function importPrivateKey(privateKeyPem: string): Promise<CryptoKey> {
  let normalized = privateKeyPem.trim();
  if (
    (normalized.startsWith('"') && normalized.endsWith('"')) ||
    (normalized.startsWith("'") && normalized.endsWith("'"))
  ) {
    normalized = normalized.slice(1, -1);
  }
  normalized = normalized.replace(/\\n/g, "\n").trim();
  const pemBody = normalized
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");

  const binaryDer = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  return await crypto.subtle.importKey(
    "pkcs8",
    binaryDer.buffer,
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"],
  );
}

async function getGoogleAccessToken(): Promise<string> {
  const clientEmail = getRequiredEnv("FIREBASE_CLIENT_EMAIL");
  const privateKey = getRequiredEnv("FIREBASE_PRIVATE_KEY");

  const now = Math.floor(Date.now() / 1000);
  const header = {
    alg: "RS256",
    typ: "JWT",
  };

  const payload = {
    iss: clientEmail,
    scope: GOOGLE_FCM_SCOPE,
    aud: GOOGLE_OAUTH_TOKEN_URL,
    iat: now,
    exp: now + 3600,
  };

  const encoder = new TextEncoder();
  const encodedHeader = toBase64Url(encoder.encode(JSON.stringify(header)));
  const encodedPayload = toBase64Url(encoder.encode(JSON.stringify(payload)));
  const unsignedJwt = `${encodedHeader}.${encodedPayload}`;

  const key = await importPrivateKey(privateKey);
  const signatureBuffer = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    encoder.encode(unsignedJwt),
  );
  const signature = toBase64Url(new Uint8Array(signatureBuffer));
  const assertion = `${unsignedJwt}.${signature}`;

  const tokenRes = await fetch(GOOGLE_OAUTH_TOKEN_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  if (!tokenRes.ok) {
    const errorText = await tokenRes.text();
    throw new Error(`Failed to get Google access token: ${errorText}`);
  }

  const tokenJson = await tokenRes.json();
  if (!tokenJson.access_token) {
    throw new Error("Google OAuth response missing access_token");
  }

  return tokenJson.access_token as string;
}

export async function sendFcmPush({
  token,
  title,
  body,
  data,
}: SendFcmPushArgs) {
  if (!token) return;

  const projectId = getRequiredEnv("FIREBASE_PROJECT_ID");
  const accessToken = await getGoogleAccessToken();

  const dataPayload = Object.fromEntries(
    Object.entries(data ?? {}).map(([key, value]) => [key, String(value)]),
  );

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: {
            title,
            body,
          },
          data: dataPayload,
          android: {
            priority: "HIGH",
            notification: {
              channel_id: "slickbills_default",
            },
          },
          apns: {
            headers: {
              "apns-priority": "10",
            },
            payload: {
              aps: {
                sound: "default",
              },
            },
          },
        },
      }),
    },
  );

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`FCM send failed: ${errorText}`);
  }
}

export function fcmUserFacingError(error: unknown): string {
  const text = error instanceof Error ? error.message : String(error);
  const lower = text.toLowerCase();
  if (
    lower.includes("invalid_grant") ||
    lower.includes("account not found") ||
    lower.includes("failed to get google access token")
  ) {
    return "Push credentials on this server are invalid. Check FIREBASE_CLIENT_EMAIL and FIREBASE_PRIVATE_KEY.";
  }
  if (
    lower.includes("unregistered") ||
    lower.includes("not_found") ||
    lower.includes("requested entity was not found")
  ) {
    return "Receiver's notification token is no longer valid. They need to open the app again.";
  }
  if (lower.includes("missing required env var")) {
    return "Push is not configured on this server (missing FIREBASE_* secrets).";
  }
  return text;
}

export async function sendFcmPushBestEffort(args: SendFcmPushArgs) {
  try {
    await sendFcmPush(args);
  } catch (error) {
    console.error(
      "FCM send skipped:",
      error instanceof Error ? error.message : error,
    );
  }
}
