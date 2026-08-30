# Loyalty & Merchant Insights — Architecture Plan

> Flutter: `lib/feature_loyalty/` · Backend: Postgres functions + triggers (no Edge Functions)

## What to build first

| Order | Deliverable | Why |
|-------|-------------|-----|
| **1** | DB migration (tables, RLS, trigger on `PAID`) | Single source of truth; atomic upserts |
| **2** | Merchant **Customers** screen (business users) | Landing-page promise; no funding/legal blockers |
| **3** | User **Rewards** card + claim flow (Phase 0) | Accumulate-only; separate from Monerium UI |
| **4** | Profile/dashboard polish, badges, empty states | |
| **5** | Expiry cron (`pg_cron` or scheduled job) | After ledger is stable |
| **6** | Redemption (Phase 1) | Only after funding + counsel |

**Do not start with:** redeem at pay, merchant cashback config, Edge Functions.

---

## Flutter: `feature_loyalty`

```
lib/feature_loyalty/
├── locales/en_locale.dart
├── models/
│   ├── rewards_summary_model.dart
│   ├── rewards_ledger_entry_model.dart
│   └── merchant_customer_link_model.dart
├── repos/
│   ├── rewards_repo.dart          # rpc: claim, list, summary
│   └── merchant_insights_repo.dart # rpc: dashboard, customer list
├── screens/
│   ├── rewards_screen.dart        # user: balance, claim, history
│   └── merchant_customers_screen.dart
└── widgets/
    ├── rewards_summary_card.dart  # profile entry
    ├── claim_rewards_banner.dart
    ├── merchant_customer_row.dart
    └── merchant_insights_kpi_row.dart
```

**Integration points**

| Location | Widget |
|----------|--------|
| `profile.dart` | `RewardsSummaryCard` (all users) |
| Business profile / sent area | nav → `MerchantCustomersScreen` |
| `shared_locales/locale_en.dart` | merge `loyaltyLocales_EN` |

**Pattern:** repos call `Supabase.instance.client.rpc(...)` — same as rest of app, no new network layer.

Optional later: `RewardsController` (GetX) if profile + rewards screen need shared reactive state.

---

## Identity in DB vs merchant UI

**Stored in Postgres (real data, server-side only):**

- `merchant_private_user_id` — the business account
- `customer_private_user_id` — the paying user (FK → `private_users`; username via join to `users`)

No `customer_username` on the link row — avoid duplication; join inside RPC when internal/opt-in needs it.

**Merchant app never receives:** `customer_private_user_id`, username, email, or IBAN (default tier).

**Merchant app shows:** “This user” + loyalty badge + aggregated stats per link row.

The link row is keyed by real ids so stats accumulate correctly; privacy is enforced by **RLS + RPC column selection + Flutter**, not by avoiding ids in the database.

---

### Tables

```sql
-- Platform rewards (Phase 0: accumulate only)
rewards_ledger (
  id, private_user_id, type, amount, status,
  invoice_id, expires_at, created_at
)
rewards_wallet_cache (
  private_user_id PK,
  pending_amount, locked_amount,  -- active_amount later
  updated_at
)

-- Merchant ↔ customer (ids + stats only; username via join)
merchant_customer_links (
  merchant_private_user_id,
  customer_private_user_id references private_users(id),
  first_paid_at, last_paid_at,
  paid_invoice_count, total_paid_eur,
  PRIMARY KEY (merchant_private_user_id, customer_private_user_id)
)

platform_config (
  key text PK, value jsonb
)  -- rewards_earn_enabled, redemption_enabled, earn_rate_bps, ...
```

### DB functions (atomic)

| Function | Purpose |
|----------|---------|
| `on_invoice_paid()` | **Trigger** on `digital_invoices` when status → `PAID` |
| `rewards_earn_for_invoice(invoice_id)` | Insert `PENDING` earn row (if enabled) |
| `rewards_claim_pending(private_user_id)` | `PENDING` → `LOCKED`, set `expires_at` +2y |
| `rewards_get_summary(private_user_id)` | Balance + recent rows |
| `merchant_get_dashboard(merchant_private_user_id)` | KPI aggregates |
| `merchant_list_customers(...)` | Stats + badge only — **excludes** `customer_username` unless opt-in flag |

**Trigger flow (one transaction on PAID):**

```text
UPDATE digital_invoices SET status = 'PAID'
  → TRIGGER on_invoice_paid
      → upsert merchant_customer_links (ids + stats)
      → rewards_earn_for_invoice (if earn enabled)
```

All logic in Postgres = atomic, no race between earn and merchant stats.

### RLS

| Table | Policy |
|-------|--------|
| `rewards_ledger` | User reads own rows (`private_user_id` = auth mapping) |
| `merchant_customer_links` | Merchant reads rows where `merchant_private_user_id` = caller's business private user |
| `rewards_claim_pending` | Via `SECURITY DEFINER` RPC only; no direct client insert |

Client **never** writes ledger or links directly — only via `SECURITY DEFINER` RPCs with `auth.uid()` checks inside.

### Merchant display vs storage

| Layer | Username |
|-------|----------|
| **Link table** | Not stored — only `customer_private_user_id` |
| **Internal RPC** | `JOIN private_users → users` when needed |
| **merchant_list_customers (default)** | Omitted — UI shows **“This user”** |
| **Future opt-in** | RPC may include username from join |

`customer_private_user_id` never returned to merchant client.

---

## Loyalty badge (computed in RPC, not stored)

```sql
CASE
  WHEN paid_invoice_count >= 3 AND last_paid_at > now() - interval '90 days' THEN 'regular'
  WHEN paid_invoice_count >= 2 THEN 'returning'
  ELSE 'new'
END
```

Merchant sees: **This user** · **Regular** · 5 paid · €240

---

## Phase 0 behaviour flags

```json
{ "rewards_earn_enabled": true, "rewards_redemption_enabled": false, "earn_rate_bps": 100 }
```

Flutter hides “Apply credits” at pay until `redemption_enabled`.

---

## What stays elsewhere

| Concern | Where |
|---------|--------|
| Invoice → PAID | Existing settlement / `update-invoice-status` (unchanged) |
| Monerium EUR | `feature_auth` / `feature_dashboard` — never mix |
| Pay flow | No rewards deduction in Phase 0 |

---

## Migration checklist

1. `supabase migration new loyalty_foundation`
2. Tables + indexes + RLS
3. Functions + trigger on `digital_invoices`
4. Seed `platform_config`
5. Manual test: mark invoice PAID → link row + pending earn
6. Flutter `feature_loyalty` + repos
7. Merchant screen → user rewards screen

---

## Testing (manual beta)

- [ ] Business sends invoice → customer pays → merchant sees **This user** + stats
- [ ] Same customer pays again → badge upgrades to Returning/Regular (same generic label)
- [ ] Customer sees pending rewards → claim → locked balance
- [ ] Merchant cannot query other merchant's links
- [ ] Customer cannot see merchant dashboard RPC

---

## Related docs

- [SlickBills Rewards Program](./slickbills-rewards-program.md)
- [Merchant Customer Insights](./merchant-customer-insights.md)
