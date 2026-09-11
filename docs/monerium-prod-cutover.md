# Monerium sandbox → production cutover

SlickBills invoices stay in Supabase. Production only changes **where orders and EURe live**. Until these env vars move, Express still talks to **sandbox** (`https://api.monerium.dev`).

Do this as one cutover. Do not mix sandbox credentials with Polygon mainnet Alchemy, or prod API with the Amoy EURe contract.

---

## What does not change

- Invoice tables / settlement matching in `vercel/express` (`digital_invoices`, `public_digital_invoices`)
- App hosts: `app.slickbills.com`, `wallet.slickbills.com`
- Express host (today): `https://express-ten-xi.vercel.app`
- Pay path: Monerium **redeem to IBAN**, not a custom invoice contract

---

## 1. Monerium portal (production app)

Create / use the **production** application at [monerium.app](https://monerium.app) (not sandbox.monerium.dev).

Register **exactly**:

| Portal field | Value |
| --- | --- |
| Redirect URI | `https://express-ten-xi.vercel.app/monerium/oauth/callback` |
| SIWE domain | Host of `PUBLIC_SERVER_URL` → `express-ten-xi.vercel.app` |
| SIWE chain ID | `137` (Polygon mainnet) |
| Statement / privacy / terms | Must match env below, character for character |

Sandbox client id/secret, IBANs, profiles, and refresh tokens **do not work** in prod. Testers KYC on **monerium.app**. After cutover, everyone reconnects Monerium in the app (wipe `monerium_tokens` rows if SIWE fails on stale sandbox tokens).

---

## 2. Vercel (Express) — must change

Project that serves `https://express-ten-xi.vercel.app`.

| Variable | Sandbox (now) | Production |
| --- | --- | --- |
| `MONERIUM_BASE_URL` | `https://api.monerium.dev` (code default) | `https://api.monerium.app` |
| `MONERIUM_CLIENT_ID` | sandbox app | **prod** app id |
| `MONERIUM_CLIENT_SECRET` | sandbox app | **prod** app secret |
| `MONERIUM_REDIRECT_URI` | sandbox callback | `https://express-ten-xi.vercel.app/monerium/oauth/callback` |
| `PUBLIC_SERVER_URL` | same host is fine | `https://express-ten-xi.vercel.app` |
| `MONERIUM_WALLET_CHAIN` | `polygon` or `polygon:amoy` | `polygon` |
| `MONERIUM_SIWE_CHAIN_ID` | `80002` if Amoy | `137` |
| `MONERIUM_EURE_TOKEN_ADDRESS` | Amoy EURe | Polygon EURe `0xE0aEa583266584DafBB3f9C3211d5588c73fEa8d` |
| `MONERIUM_NETWORK_ADDRESS` | same as above if used | same Polygon EURe address |
| `MONERIUM_STATE_SECRET` | may fall back to `"dev-monerium-state-secret"` | set a long random secret (not the default) |

Leave path overrides alone unless Monerium tells you otherwise (`/auth`, `/auth/token`, `/addresses`, `/ibans`, `/orders`, `/profiles`).

**SIWE strings** — copy from the prod app, or keep current defaults only if the portal matches them:

```text
MONERIUM_SIWE_APP_NAME=Slickbills
MONERIUM_SIWE_STATEMENT=Allow Slickbills to access my data on Monerium
MONERIUM_PRIVACY_URL=https://slickbills.com/privacy-policy
MONERIUM_TERMS_URL=https://slickbills.com/terms
```

Redeploy Express after saving env.

---

## 3. Alchemy — Polygon mainnet

Settlement watches **ERC-20 activity on EURe**, then loads the Monerium order.

| Variable | Production |
| --- | --- |
| `ALCHEMY_NETWORK_URL` | Polygon **mainnet** HTTPS RPC (not Amoy) |
| `ALCHEMY_WEBHOOK_SIGNING_KEY` | signing key of the **new** webhook |
| `ALCHEMY_WEBHOOK_ID` | Address Activity webhook on Polygon mainnet |
| `ALCHEMY_NOTIFY_AUTH_TOKEN` | dashboard token so new wallets get added to the webhook |

Webhook URL (unchanged path):

```text
https://express-ten-xi.vercel.app/monerium/chain/transfers
```

Filter / contract: Polygon EURe `0xE0aEa583266584DafBB3f9C3211d5588c73fEa8d`.

The Flutter listener uses the same RPC + token via dart-define / `.env`:

```text
ALCHEMY_NETWORK_URL=https://polygon-mainnet.g.alchemy.com/v2/<key>
MONERIUM_NETWORK_ADDRESS=0xE0aEa583266584DafBB3f9C3211d5588c73fEa8d
```

`make run-mobile` / `make build-web` already pass those two. Rebuild the app after changing `.env`.

---

## 4. What you can leave

| Piece | Why |
| --- | --- |
| Supabase | Invoice state stays off-chain |
| `wallet.slickbills.com` | SIWE / sign happens there; it already calls Express |
| Web3Auth client id / network | That’s the **wallet key**, not Monerium. Changing Sapphire network gives users **new addresses** — don’t switch unless you mean to |
| Coinbase CDP / Base EURC | Not on the Monerium pay path |

`wallet-client` SIWE posts to `https://express-ten-xi.vercel.app` (hardcoded). No wallet-client env change for Monerium host.

---

## 5. Smoke test (real €, two KYC’d prod accounts)

Use €1–2.

1. Connect wallet + Monerium SIWE. IBAN shows. Balance is Polygon EURe.
2. SEPA into that IBAN → mint → balance in app.
3. A sends invoice to B. B pays. Order `processed`. Invoice **PAID**. Both notified. `moneriumOrderId` / `txHash` stored.
4. Withdraw to an external IBAN.
5. Pay the same IBAN from a normal bank with the invoice reference → still matches.

If 3 fails but the bank/EURe moved, Alchemy webhook or EURe contract address is still sandbox.

---

## 6. Quick verify after deploy

- Express logs / a test SIWE: authorize URL host is `api.monerium.app`, not `api.monerium.dev`
- SIWE log line: `chainId: 137`, `redirectUri` = the portal callback
- Alchemy dashboard: webhook is Polygon mainnet, last ping hits `/monerium/chain/transfers` with 200
- No leftover Amoy token address in Vercel or Flutter `.env`
