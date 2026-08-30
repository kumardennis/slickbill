# Merchant Customer Insights & Connections

> How SlickBills helps merchants see **loyal customers** and **payment relationships** without exposing private user data. Aligns with merchant landing-page promise: better connections and statistics through the platform.

## Goal

When a **business** sends invoices via SlickBills and customers pay, the merchant should see:

- Who comes back (repeat vs one-time)
- Spend patterns (aggregates and per-relationship summaries)
- A sense of **connection** to customers who chose SlickBills to pay them

This is **not** a CRM dump of emails/IBANs. It is **relationship analytics** derived from invoice/payment activity on-platform.

---

## Relationship model

A **merchant–customer connection** exists when:

- Merchant = invoice **sender** with `senderIsBusiness = true`
- Customer = invoice **receiver** (private user) who **paid** (`status = PAID`)

```text
digital_invoices
  sender  → business merchant
  receiver → paying customer
  status  → PAID
```

Materialized view or table: `merchant_customer_links`

| Column | Notes |
|--------|-------|
| `merchant_private_user_id` | Business operator account |
| `customer_private_user_id` | Payer — join to `private_users` → `users` for username when needed (server-side only) |
| `first_paid_at` | |
| `last_paid_at` | |
| `paid_invoice_count` | |
| `total_paid_eur` | Sum of paid amounts |
| `avg_days_to_pay` | Optional |

Updated on invoice `PAID` (trigger or job).

---

## Default privacy model: real ids in DB, “This user” in merchant UI

**Database:** `merchant_customer_links` stores only ids + stats. Username lives on `users` (via `customer_private_user_id` → `private_users.userId` → `users.username`). No duplicated `customer_username` column — join when needed inside `SECURITY DEFINER` RPCs (fine for beta scale).

**Merchant UI / RPC (default):** show **“This user”** + badge + stats. Response omits username and `customer_private_user_id`.

```text
DB:     customer_private_user_id → join → users.username (internal)
Merchant sees: "This user · Regular · 5 paid · €240"
```

Privacy enforced at **RPC + Flutter**, not by avoiding ids in the link table.

---

## Privacy tiers (summary)

### Tier 1 — Default

Generic **“This user”** in merchant UI. Username via join on `customer_private_user_id`; withheld from merchant RPC until opt-in.

### Tier 2 — Aggregate-only (extra strict)

Dashboard KPIs only — no per-customer rows.

### Tier 3 — Identity opt-in (future)

Customer chooses to reveal `@username` or name to a specific merchant.

---

## Loyalty signals (merchant-facing)

Rule-based badges — no ML required for v1:

| Badge | Rule (example) |
|-------|----------------|
| **New** | First paid invoice in last 30 days |
| **Returning** | ≥ 2 paid invoices |
| **Regular** | ≥ 3 paid in last 90 days |
| **VIP** | Top 10% by `total_paid_eur` (merchant scope) |

Optional link to SlickBills Rewards (Phase 0+): “This customer has claimed platform rewards” — boolean only, not credit amount (reduces gaming).

---

## Merchant reports (v1)

### Dashboard cards

- Unique payers this month
- Repeat customer rate
- Total received via SlickBills (EUR)
- Avg days to pay

### Customer list (default)

Sortable table:

- **Label** — always “This user”
- **Badge** (Regular, VIP, …)
- Invoices paid · Total · Last active

Merchant message: *“This user is a regular customer — 5 paid bills, €240 total.”*

### Export (CSV)

- Generic label + badge + counts/totals only
- No real names, usernames, or internal ids

### Future

- Cohort chart (new vs returning by month)
- Category breakdown (invoice category field)
- Connection graph (merchant ↔ repeat payers count)

---

## GDPR / privacy notes

- **Lawful basis:** likely legitimate interest (B2B payment relationship) + transparency; opt-in for identifiable fields. Confirm with counsel.
- **Data minimization:** merchants get what they need to recognize loyalty, not full profiles.
- **Right to erasure:** pseudonymized link row deleted/anonymized on account delete; merchant sees “Inactive customer”.
- **No selling** customer lists to third parties.
- **RLS:** merchant can only read links where `merchant_private_user_id = auth user's business account`.

---

## Implementation sketch

1. **Migration:** `merchant_customer_links` + optional `merchant_customer_visibility`
2. **Trigger:** on invoice → `PAID`, upsert link stats
3. **Edge fn:** `get-merchant-customer-insights` (auth + business check)
4. **Flutter:** “Customers” tab on business profile / sent bills (business mode only)
5. **Reuse:** extend existing `StatisticsCard` pattern for merchant KPIs

---

## Landing page alignment

Merchant promise: *SlickBills helps you know your customers and grow repeat business through the invoices they already pay.*

Delivery path:

| Promise | Product |
|---------|---------|
| Statistics | Dashboard KPIs + monthly summary |
| Connection | Persistent merchant–customer link from paid invoices |
| Loyalty | Badges + repeat rate (merchant loyalty programs = later) |
| Privacy | Real ids in link table; username via join; merchant sees “This user” |

---

## Out of scope (v1)

- Merchant-funded cashback / loyalty rules
- Cross-merchant customer identity (each merchant sees only their own links)
- Marketing email blast to customers
- Sharing data with external analytics tools

---

## Related

- [SlickBills Rewards Program](./slickbills-rewards-program.md) — platform credits (separate from merchant insights).
