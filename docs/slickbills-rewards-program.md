# SlickBills Rewards Program (Platform Credits)

> Internal product + compliance reference. Not legal advice. Counsel review required before public launch.

## Purpose

SlickBills Rewards are **promotional platform credits** — a bonus for using SlickBills. They are **not** electronic money, not user deposits, and **not** part of the Monerium EUR balance.

Monerium handles regulated EUR. SlickBills handles a separate, closed-loop rewards ledger.

## Regulatory principles

| Principle | Implementation |
|-----------|----------------|
| Not e-money | Credits are issued **gratuitously** (never sold). No 1:1 EUR backing claim. |
| Separate from Monerium | Distinct UI label, ledger, and API. Never mix balances. |
| Closed loop | Redeem only inside SlickBills (invoice payment discount), when enabled. |
| No cash-out | No IBAN withdraw, bank transfer, or P2P send of credits. |
| User claim | Earn → user explicitly **claims** → credits become locked/active in ledger. |
| Platform-funded | Merchant is **never** short-paid because of credits (see phases). |
| Expiry | **2 years** from claim date (configurable). FIFO spend when redemption goes live. |

EU framing (high level): gratuitous bonus points used only within the SlickBills network are typically treated differently from e-money issued against payment. If redemption volume grows (> ~€1M/year), assess **Limited Network Exclusion** notification with counsel.

Reference growth model: Paytm injected cashback to build habit — we copy **mechanics** (%, claim UX, campaigns), not storing promo value inside a licensed wallet.

---

## Phases

### Phase 0 — Accumulate only (launch default)

**Goal:** Build habit and ledger without moving money or affecting merchants.

- Credits **accrue** on qualifying events (e.g. invoice paid via SlickBills).
- Flow: `PENDING` (earned) → user taps **Claim** → `LOCKED` (visible, not spendable).
- **No redemption** at checkout. Monerium payment flow unchanged.
- Merchant always receives **full EUR** for every paid invoice.
- UI: “SlickBills Rewards — X accumulated — redemption coming soon.”
- Global feature flag: `rewards_redemption_enabled = false`.

**Why:** SlickBills has no funding yet to subsidize discounts. Redeeming credits against a merchant invoice without platform subsidy would mean the business receives less real money — unacceptable at this stage.

### Phase 1 — Redemption (funded + legal clearance)

**Goal:** User pays less EUR; merchant still receives full invoice amount.

- Platform **subsidy model**: user applies credits → pays reduced EUR via Monerium → SlickBills (or designated promo account) covers the discount so **merchant settlement stays whole**.
- Requires: promo budget, accounting treatment, counsel sign-off, merchant terms update.
- Status flow adds `ACTIVE` (spendable) and `REDEEMED` / `EXPIRED`.

### Phase 2 — Campaigns & caps

- First-payment bonus, referral rewards, % back with per-user/month caps.
- Admin-configurable earn rules.
- Merchant-specific loyalty (optional, separate doc) — **not** in Phase 0/1.

---

## Credit lifecycle

```
EARN (pending)  →  CLAIM (locked)  →  [later] ACTIVE  →  REDEEM / EXPIRE
     ↑                    ↑                              ↑
  on PAID txn        user action                   Phase 1 only
```

| Status | Spendable | Shown to user |
|--------|-----------|---------------|
| `PENDING` | No | “Tap to claim X rewards” |
| `LOCKED` | No | “X rewards saved — redeem soon” |
| `ACTIVE` | Yes (Phase 1+) | Usable at pay time |
| `REDEEMED` | — | History |
| `EXPIRED` | No | History |

**Pending expiry:** unclaimed pending credits may expire (e.g. 30 days) — TBD.

**Active expiry:** 2 years from claim.

---

## Data model (draft)

### `rewards_ledger`

Append-only audit trail.

| Column | Notes |
|--------|-------|
| `id` | PK |
| `user_id` | `private_users.id` or auth-scoped id |
| `type` | `EARN`, `CLAIM`, `REDEEM`, `EXPIRE`, `ADJUST` |
| `amount` | Decimal, always positive; sign implied by type |
| `status` | `PENDING`, `LOCKED`, `ACTIVE`, … |
| `invoice_id` | Optional link to triggering invoice |
| `expires_at` | Set on claim |
| `created_at` | |

Cached balance on `rewards_wallets` (recomputable from ledger).

### Platform config

| Key | Default |
|-----|---------|
| `rewards_redemption_enabled` | `false` |
| `rewards_earn_enabled` | `true` (Phase 0) |
| `rewards_earn_rate_bps` | TBD (e.g. 100 = 1%) |
| `rewards_monthly_cap_per_user` | TBD |
| `rewards_global_outstanding_cap` | TBD |

---

## Earn rules (Phase 0 starter)

- Trigger: `digital_invoices.status` → `PAID`, payer used SlickBills/Monerium flow.
- Amount: small % of invoice or flat micro-bonus — keep low until funded.
- Create `EARN` row as `PENDING`; notify user to claim.

---

## UX requirements

1. **Visual separation:** “Rewards” ≠ “Balance (EUR)”.
2. **Terms link:** promotional, no cash value, program may change, not a deposit.
3. **Claim screen:** explicit consent to program terms.
4. **History:** earned / claimed / expired list.

---

## What we do not do

- Sell credit packs.
- Credit Monerium wallet.
- Let merchants fund cashback in Phase 0 (config comes later).
- Reduce merchant EUR payout without platform subsidy.

---

## Open decisions

- [ ] Earn rate and caps for beta
- [ ] Pending claim window before forfeit
- [ ] Pause expiry clock while `LOCKED`?
- [ ] Legal review (EEA entity / Finantsinspektsioon or relevant NCA)
- [ ] Accounting: rewards liability on SlickBills books

---

## Related

- [Merchant customer insights](./merchant-customer-insights.md) — loyalty signals for businesses (privacy-safe).
