# SlickBills — what the app can do

Internal technical inventory for a business plan. Source of truth is `master` / `production` (same code). Not legal advice.

## What it is

- Euro payment-request app: create a named € bill, track UNPAID → PROCESSING → PAID, keep proof.
- SlickBills does **not** hold customer euros. Monerium is the regulated IBAN / EURe rail.
- iOS, Android, web (`app.slickbills.com` / `app-staging.slickbills.com`).

## Who

- One login (email / Google / Facebook). No Apple Sign-In.
- Same account can be **personal** or **business** (`isBusiness` flag + optional public name). Not a second legal entity in-app.
- Roles on a bill: sender, receiver, public-link guest, claimer.
- Merchant extras only if `isBusiness`: checkout QR, cashier, customer insights.

## What it can do

- Sign up / sign in; optional biometrics (mobile only, not web).
- Connect wallet (Privy / MetaMask) + Monerium → euro IBAN + KYC status.
- Or save a manual bank IBAN + account-holder name.
- Send a private bill by username (1:1 or group).
- Send a public bill as link/QR (`/bill/:token`), NFC/nearby request.
- Receive, remind, reject (PROCESSING → UNPAID), pay in-app.
- Claim a public bill into a private invoice (must be signed in).
- Withdraw Monerium balance to an external IBAN.
- Business: public name, CSV export, merchant check-in `/m/:token`.
- Rewards: personal user **earns** credits when paying a business (accumulate only).
- Push (FCM) + Firebase Analytics (no IBAN / names / amounts).
- Search received / sent / public lists by the other party’s name or description (substring + typo-tolerant).

## Payment confirmation file (later phase)

In-app PAID is the live proof. A downloadable HTML→PDF confirmation is **not this slice**: customers already keep bank receipts, and storing files in Supabase Storage adds cost.

When we do it: one stored PDF per bill, same bytes for both parties, labeled **Payment confirmation** (not a VAT invoice). No EdenAI / PDF.co.

## Invoice types

| Type | Who sees it | Pay |
|---|---|---|
| Private | sender + receiver only | In-app Monerium and/or bank transfer to sender IBAN |
| Public | guest via token only (no table dump) | Guest: bank transfer. In-app pay after claim |
| Group / session | parties on that bill | Same as private |

## Allowed money paths

- In-app pay: Monerium **redeem → sender IBAN**, memo `[sb:{invoiceId}]`. Needs wallet + Monerium + balance + destination IBAN + email.
- External bank SEPA to sender’s Monerium IBAN (amount + reference / IBAN match). Express marks paid.
- Public bill: pay from any bank using shown IBAN + memo, no account required.
- Public bill: sign in → claim → then in-app pay.
- SEPA in → mint → EURe balance (fund own wallet).
- Withdraw EURe → own external IBAN.

## Blocked / not the live product

- Guest **Pay** on a public bill (no in-app pay without claim).
- Send a bill with no sender IBAN / account-holder name.
- Pay with no destination IBAN, no wallet, no Monerium session, or no balance.
- Anon read of invoice tables (guests only `get_public_invoice_by_token`).
- Mixing staging ↔ production (DB, Monerium sandbox vs live, wallets).
- Coinbase / Base EURC as invoice settle (legacy pages, not Pay).
- Striga / open-banking TPP (dead backend, not UI).
- Rewards as money: no cash-out, no IBAN, no P2P, **no checkout discount** (`rewards_redemption_enabled = false`).
- Rewards earn: not on P2P, not when the **payer** is a business.
- Merchant insights: no customer email / username / IBAN.
- App lock on web: off.
- EdenAI / PDF.co (OCR parse). Dead for this product; remove. OpenAI text-extract on pasted PDF text is a separate leftover, not confirmation PDFs.

## Access (who is allowed)

- Private invoice: only its sender or receiver.
- Public invoice row: owner or claimer; guest gets a limited token view (amount, IBAN, memo, business name).
- Claim: authenticated only.
- Merchant RPCs: `isBusiness` required.
- Invoice create/settle: server/Edge/Express, not open client inserts.

## Hard constraints for a plan

- Currency: **EUR only** (Monerium redeem).
- Pay rail: **to IBAN**, not a custom crypto invoice contract.
- Bank/Monerium name = legal **account holder**, not marketing `publicName`.
- SlickBills is a **request + match + proof** layer, not an e-money issuer.
- Rewards are promotional credits, not deposits; merchant is always paid **full EUR**.
- Two stacks: staging vs production; never mix money or databases.

## Related docs

- `docs/prod-migration.md` — staging vs production stacks
- `docs/monerium-prod-cutover.md` — Monerium rail
- `docs/slickbills-rewards-program.md` — credits (not e-money)
- `docs/loyalty-architecture-plan.md` / `docs/merchant-checkout-qr.md` / `docs/merchant-customer-insights.md`
