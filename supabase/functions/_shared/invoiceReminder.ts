import { sendFcmPush } from "./fcm.ts";

export const MANUAL_REMIND_COOLDOWN_MS = 24 * 60 * 60 * 1000;
export const AUTO_REMIND_COOLDOWN_MS = 3 * 24 * 60 * 60 * 1000;
export const SKIP_RECENTLY_CREATED_MS = 20 * 60 * 60 * 1000;

export type ReminderInvoice = {
  id: number;
  status: string;
  isObsolete: boolean | null;
  deadline: string | null;
  amount: number | null;
  senderName: string | null;
  senderPrivateUserId: number | null;
  receiverPrivateUserId: number | null;
  lastRemindedAt: string | null;
  created_at: string | null;
};

type ReminderSupabase = {
  from: (table: string) => {
    select: (columns: string) => {
      eq: (column: string, value: unknown) => {
        maybeSingle: () => Promise<{ data: Record<string, unknown> | null }>;
        single: () => Promise<{ data: Record<string, unknown> | null }>;
      };
    };
    update: (values: Record<string, unknown>) => {
      eq: (column: string, value: unknown) => Promise<unknown>;
    };
  };
};

export function todayInTallinn(): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Tallinn",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
}

export function dateOnly(value: string | null | undefined): string {
  if (!value) return "";
  return value.slice(0, 10);
}

export function reminderCopy(invoice: ReminderInvoice): {
  title: string;
  body: string;
} {
  const today = todayInTallinn();
  const deadline = dateOnly(invoice.deadline);
  const name = invoice.senderName?.trim() || "Someone";
  const amount = typeof invoice.amount === "number"
    ? `€${invoice.amount.toFixed(2)}`
    : "a slickbill";

  if (deadline && deadline < today) {
    return {
      title: "Payment reminder",
      body: `${name} is waiting for ${amount}. This slickbill is overdue (due ${deadline}).`,
    };
  }

  if (deadline === today) {
    return {
      title: "Payment due today",
      body: `${name} is waiting for ${amount}. Due today.`,
    };
  }

  return {
    title: "Payment reminder",
    body: `${name} is waiting for ${amount}${deadline ? `. Due ${deadline}` : ""}.`,
  };
}

export function isUnpaidOpen(invoice: ReminderInvoice): boolean {
  const status = (invoice.status ?? "").trim().toUpperCase();
  return status === "UNPAID" && invoice.isObsolete !== true;
}

export function cooldownRemainingMs(
  lastRemindedAt: string | null | undefined,
  cooldownMs: number,
): number {
  if (!lastRemindedAt) return 0;
  const last = Date.parse(lastRemindedAt);
  if (Number.isNaN(last)) return 0;
  return Math.max(0, last + cooldownMs - Date.now());
}

export function isEligibleForAutoReminder(invoice: ReminderInvoice): boolean {
  if (!isUnpaidOpen(invoice)) return false;

  const deadline = dateOnly(invoice.deadline);
  const today = todayInTallinn();
  if (!deadline || deadline > today) return false;

  if (invoice.created_at) {
    const created = Date.parse(invoice.created_at);
    if (!Number.isNaN(created) && Date.now() - created < SKIP_RECENTLY_CREATED_MS) {
      return false;
    }
  }

  return cooldownRemainingMs(invoice.lastRemindedAt, AUTO_REMIND_COOLDOWN_MS) === 0;
}

export async function deliverInvoiceReminder(
  supabase: ReminderSupabase,
  invoice: ReminderInvoice,
): Promise<{ sent: boolean; error?: string; lastRemindedAt?: string }> {
  if (!invoice.receiverPrivateUserId) {
    return { sent: false, error: "Invoice has no receiver" };
  }

  const { data: privateUser } = await supabase
    .from("private_users")
    .select("userId")
    .eq("id", invoice.receiverPrivateUserId)
    .maybeSingle();

  const userId = privateUser?.userId as number | undefined;
  if (!userId) {
    return { sent: false, error: "Receiver user not found" };
  }

  const { data: user } = await supabase
    .from("users")
    .select("fcm_token")
    .eq("id", userId)
    .maybeSingle();

  const fcmToken = (user?.fcm_token as string | null) ?? "";
  if (!fcmToken) {
    return { sent: false, error: "Receiver has no push notifications enabled" };
  }

  const copy = reminderCopy(invoice);
  await sendFcmPush({
    token: fcmToken,
    title: copy.title,
    body: copy.body,
    data: {
      type: "payment_reminder",
      invoiceId: invoice.id,
    },
  });

  const lastRemindedAt = new Date().toISOString();
  await supabase
    .from("digital_invoices")
    .update({ lastRemindedAt })
    .eq("id", invoice.id);

  return { sent: true, lastRemindedAt };
}
