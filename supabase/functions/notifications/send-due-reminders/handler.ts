import { corsHeaders } from "../../_shared/cors.ts";
import {
  createSupabaseService,
  isServiceRoleRequest,
} from "../../_shared/supabaseClient.ts";
import {
  deliverInvoiceReminder,
  isEligibleForAutoReminder,
  todayInTallinn,
  type ReminderInvoice,
} from "../../_shared/invoiceReminder.ts";

export const handler = async (req: Request) => {
  if (!isServiceRoleRequest(req)) {
    return new Response(
      JSON.stringify({
        isRequestSuccessfull: false,
        data: null,
        error: "Unauthorized",
      }),
      {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  const supabase = createSupabaseService();
  const today = todayInTallinn();

  try {
    const { data: rows, error } = await supabase
      .from("digital_invoices")
      .select(
        "id, status, isObsolete, deadline, amount, senderName, senderPrivateUserId, receiverPrivateUserId, lastRemindedAt, created_at",
      )
      .eq("status", "UNPAID")
      .eq("isObsolete", false)
      .lte("deadline", today);

    if (error) {
      return new Response(
        JSON.stringify({
          isRequestSuccessfull: false,
          data: null,
          error,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const invoices = (rows ?? []) as ReminderInvoice[];
    const eligible = invoices.filter(isEligibleForAutoReminder);

    const results: Array<{ invoiceId: number; sent: boolean; error?: string }> =
      [];

    for (const invoice of eligible) {
      try {
        const result = await deliverInvoiceReminder(supabase as never, invoice);
        results.push({
          invoiceId: invoice.id,
          sent: result.sent,
          error: result.error,
        });
      } catch (err) {
        results.push({
          invoiceId: invoice.id,
          sent: false,
          error: err instanceof Error ? err.message : String(err),
        });
      }
    }

    return new Response(
      JSON.stringify({
        isRequestSuccessfull: true,
        data: {
          today,
          considered: invoices.length,
          eligible: eligible.length,
          sent: results.filter((r) => r.sent).length,
          results,
        },
        error: null,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({
        isRequestSuccessfull: false,
        data: null,
        error: err instanceof Error ? err.message : String(err),
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
};
