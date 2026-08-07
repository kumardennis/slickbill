const ALCHEMY_UPDATE_URL =
  "https://dashboard.alchemy.com/api/update-webhook-addresses";

export const addAddressesToAlchemyWebhook = async (
  addresses: string[],
): Promise<{ ok: boolean; detail?: string; skipped?: boolean }> => {
  const authToken = process.env.ALCHEMY_NOTIFY_AUTH_TOKEN?.trim();
  const webhookId = process.env.ALCHEMY_WEBHOOK_ID?.trim();

  if (!authToken || !webhookId) {
    return {
      ok: false,
      skipped: true,
      detail: "ALCHEMY_NOTIFY_AUTH_TOKEN or ALCHEMY_WEBHOOK_ID missing",
    };
  }

  const cleaned = [
    ...new Set(
      addresses
        .map((a) => a.trim().toLowerCase())
        .filter((a) => /^0x[a-f0-9]{40}$/.test(a)),
    ),
  ];

  if (cleaned.length === 0) {
    return { ok: true, skipped: true, detail: "no_addresses" };
  }

  // Alchemy accepts max 500 per request.
  for (let i = 0; i < cleaned.length; i += 500) {
    const batch = cleaned.slice(i, i + 500);
    const response = await fetch(ALCHEMY_UPDATE_URL, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-Alchemy-Token": authToken,
      },
      body: JSON.stringify({
        webhook_id: webhookId,
        addresses_to_add: batch,
        addresses_to_remove: [],
      }),
    });

    if (!response.ok) {
      const text = await response.text();
      return {
        ok: false,
        detail: `http_${response.status}:${text.slice(0, 300)}`,
      };
    }
  }

  return { ok: true, detail: `added_${cleaned.length}` };
};
