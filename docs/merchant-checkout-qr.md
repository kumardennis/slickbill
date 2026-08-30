# Merchant checkout QR & check-in sessions

> Printed QR at the register. Customer scans **before pay** → **open visit session** → cashier sees live queue → merchant bills from session (planned) → customer pays in app → cashier **closes session**.

---

## Physical setup

Merchant prints QR (Profile → **Checkout QR**) and sticks it at the cash register. Same QR forever unless rotated.

```text
QR: https://app.slickbills.com/m/{checkoutToken}
DB: checkout_token per business merchant (opaque, not encrypted)
```

**Checkout QR = “I’m here.”** It is not a payment QR. Payment happens via SlickBill in the app (no second scan).

---

## Two paths

| Path | Session | When merchant sees insights |
|------|---------|----------------------------|
| **A. Check-in** | **Open** → cashier closes | **During session** on cashier screen |
| **B. Pay only** | None | **After PAID** in customer history / KPIs |

---

## Target model: group sessions (planned)

One **session** = one visit / table / group. **Multiple customers** can join the same session (bill splitting).

### Opaque display tokens (privacy-friendly)

Not encrypted usernames — random labels from word lists only. Never derived from identity.

| Level | Format | Example | Purpose |
|-------|--------|---------|---------|
| **Session** | 3 words | `QuickBlueOak` | Group / table visit — merchant queue row |
| **Member** | 2 words + 2 digits | `SlyFox12` | Person inside that session — split bills, call-out at counter |

**Merchant sees:**

```text
QuickBlueOak · 3 people · 4m ago
  SlyFox12   · Returning
  RedOak47   · New
  BoldWave03 · Regular
```

**Customer sees:** *“You’re **SlyFox12** in visit **QuickBlueOak** at [Cafe].”*

Lifetime history / KPIs still use **“This user”** — tokens are for **live OPEN visits only**.

### Re-scan / join rules

When customer scans checkout QR:

1. **Already a member** of an OPEN session at this merchant → return same session + same member token (refresh last seen; no duplicate).
2. **Else** → **Start new visit** (new 3-word session + member token) **or** **Join visit** (enter/pick session token → assign new member token).

One membership per customer per OPEN session. Prefer lookup-before-create on every scan.

### Billing (planned)

- Merchant taps session or member → `merchant_create_invoice_for_session(...)` (server resolves customer from `session_id` / member row).
- Customer receives normal received-invoice flow — no payment QR.
- Split: invoice lines tied to member tokens; each person pays their share.
- Optional later: auto-close session when all members paid or idle timeout.

---

## Shipped today (v1 — per-customer sessions)

> **Superseded by 3d (group sessions).** Apply `20260830173630_loyalty_group_sessions_3d.sql`.

```text
Customer scans QR → merchant_check_in(token)
  → upsert merchant_customer_links
  → one OPEN row in merchant_check_in_sessions (per customer per merchant)

Cashier: MerchantCashierScreen — multiple OPEN rows, all labeled "This user"
Close: merchant_close_check_in_session(session_id)
Realtime: merchant_cashier_events → app bar badge + check-in alert sheet
```

| Step | Status |
|------|--------|
| 3a — checkout token + sessions migration | ✅ |
| 3b — merchant QR, cashier, scan landing | ✅ |
| 3c — customer bottom sheet + My merchants | ✅ |
| Realtime cashier events + app bar quick access | ✅ |

---

## Planned schema (group sessions)

### `merchant_check_in_sessions`

| Column | Notes |
|--------|-------|
| `id` | PK |
| `merchant_private_user_id` | |
| `session_token` | 3 words, e.g. `QuickBlueOak` — unique among OPEN at merchant |
| `status` | `OPEN` \| `CLOSED` |
| `opened_at`, `closed_at` | |
| `closed_by_merchant_private_user_id` | nullable |

Remove `customer_private_user_id` from session row (moves to members table).

### `merchant_check_in_session_members`

| Column | Notes |
|--------|-------|
| `session_id` | FK → sessions |
| `customer_private_user_id` | never sent to merchant client |
| `member_token` | 2 words + 2 digits, e.g. `SlyFox12` — unique within session |
| `joined_at`, `last_seen_at` | |

Constraint: at most one OPEN session membership per `(customer, merchant)` (customer cannot sit in two open visits at same shop).

### `merchant_checkout_qr` (unchanged)

| Column | Notes |
|--------|-------|
| `merchant_private_user_id` | PK |
| `checkout_token` | unique, public in QR |

### `merchant_customer_links` (unchanged — lifetime stats)

Check-in counters + paid stats. Updated on join/check-in RPC and PAID trigger.

---

## RPCs

### Shipped

| RPC | Caller | Action |
|-----|--------|--------|
| `merchant_get_checkout_qr()` | Business | token + URL |
| `merchant_check_in(p_checkout_token)` | Customer | link upsert + OPEN session (v1) |
| `merchant_list_open_sessions()` | Business | cashier list |
| `merchant_close_check_in_session(p_session_id)` | Business | CLOSE session |

### Planned

| RPC | Caller | Action |
|-----|--------|--------|
| `merchant_check_in(..., join_session_token?)` | Customer | find existing membership, join, or create group session + tokens |
| `merchant_list_open_sessions()` | Business | session token + member count + member list (tokens + badges) |
| `merchant_create_invoice_for_session(...)` | Business | bill session or member; server-side customer resolve |
| Auto-close on PAID | System | optional trigger |

---

## Privacy

- QR token ≠ merchant id.
- Merchant client never receives `customer_private_user_id` or username (default tier).
- Session/member tokens are random opaque labels — not reversible to identity.
- Billing and joins use `SECURITY DEFINER` RPCs with server-side id resolution.

---

## Flutter

### Shipped (`lib/feature_loyalty/`)

- `MerchantCheckoutQrScreen`, `MerchantCashierScreen`, `MerchantCheckInLandingScreen`
- Customer check-in bottom sheet, My merchants, merchant customers / insights
- `MerchantCheckInListener`, `MerchantOpenSessionsController` (app bar badge)

### Planned

- Check-in: start vs join visit; show session + member tokens on customer sheet
- Cashier: queue by session token; expandable member rows
- Bill-from-session flow (links to existing send/receive invoice UI)

---

## Open decisions

- [ ] Join UX: type 3-word session token vs pick from open list at merchant
- [ ] Word list size / collision retry for token generation
- [ ] Max members per session
- [ ] Auto-close: all paid vs merchant manual vs idle timeout

---

## Related

- [Merchant customer insights](./merchant-customer-insights.md)
- [Loyalty architecture plan](./loyalty-architecture-plan.md)
