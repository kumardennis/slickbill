export async function sendOneSignalPush({
  externalUserId,
  heading,
  content,
  data,
}: {
  externalUserId: string;
  heading: string;
  content: string;
  data: Record<string, unknown>;
}) {
  const appId = Deno.env.get("ONESIGNAL_APP_ID") ?? "";
  const restKey = Deno.env.get("ONESIGNAL_REST_API_KEY") ?? "";
  if (!appId || !restKey) return;

  await fetch("https://api.onesignal.com/notifications?c=push", {
    method: "POST",
    headers: {
      Authorization: `Key ${restKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      app_id: appId,
      include_aliases: { external_id: [externalUserId] },
      target_channel: "push",
      headings: { en: heading },
      contents: { en: content },
      data,
    }),
  });
}
