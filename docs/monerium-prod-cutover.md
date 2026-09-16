# Monerium sandbox → production cutover

Stack split (git branches, hosts, new prod Supabase): **`docs/prod-migration.md`**. This file is only the money-path env checklist.

Prod Express is a **new** Vercel project (not `express-ten-xi`). Redirect URI, SIWE domain, and Alchemy webhook must use that prod host. Staging Express stays `https://express-ten-xi.vercel.app` + `https://api.monerium.dev`.

Do this as one cutover. Do not mix sandbox credentials with Ethereum mainnet Alchemy, or prod API with the Amoy EURe contract.

---

## What does not change

- Pay path: Monerium **redeem to IBAN**, not a custom invoice contract
- Public hosts stay `app.slickbills.com` and `wallet.slickbills.com` (prod only)
- Staging Express stays `https://express-ten-xi.vercel.app`

---

## 1. Monerium portal (production app)

Create / use the **production** application at [monerium.app](https://monerium.app) (not sandbox.monerium.dev).

Register **exactly**:

| Portal field | Value |
| --- | --- |
| Redirect URI | `https://<prod-express>/monerium/oauth/callback` |
| SIWE domain | Host of prod `PUBLIC_SERVER_URL` (prod Express, not `express-ten-xi`) |
| SIWE chain ID | `1` (Ethereum mainnet) |
| Statement / privacy / terms | Must match env below, character for character |

Sandbox client id/secret, IBANs, profiles, and refresh tokens **do not work** in prod. Testers KYC on **monerium.app**. After cutover, everyone reconnects Monerium in the app (wipe `monerium_tokens` rows if SIWE fails on stale sandbox tokens).

---

## 2. Vercel (prod Express project) — must change

Put these on the **prod** Express project only. Leave `express-ten-xi` on sandbox.

| Variable | Sandbox (`express-ten-xi`) | Production (new Express project) |
| --- | --- | --- |
| `MONERIUM_BASE_URL` | `https://api.monerium.dev` (code default) | `https://api.monerium.app` |
| `MONERIUM_CLIENT_ID` | sandbox app | **prod** app id |
| `MONERIUM_CLIENT_SECRET` | sandbox (if the old app had one) | omit for PKCE OAuth apps |
| `MONERIUM_REDIRECT_URI` | staging callback on `express-ten-xi` | `https://<prod-express>/monerium/oauth/callback` |
| `PUBLIC_SERVER_URL` | `https://express-ten-xi.vercel.app` | prod Express origin |
| `MONERIUM_WALLET_CHAIN` | `polygon` or `polygon:amoy` | `ethereum` |
| `MONERIUM_SIWE_CHAIN_ID` | `80002` if Amoy | `1` |
| `MONERIUM_EURE_TOKEN_ADDRESS` | Amoy EURe | Ethereum EURe `0x39b8B6385416f4cA36a20319F70D28621895279D` |
| `MONERIUM_NETWORK_ADDRESS` | same as above if used | same Ethereum EURe address |
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

## 3. Alchemy — Ethereum mainnet

Settlement watches **ERC-20 activity on EURe**, then loads the Monerium order.

| Variable | Production |
| --- | --- |
| `ALCHEMY_NETWORK_URL` | Ethereum **mainnet** HTTPS RPC (not Sepolia) |
| `ALCHEMY_WEBHOOK_SIGNING_KEY` | signing key of the **new** webhook |
| `ALCHEMY_WEBHOOK_ID` | Address Activity webhook on Ethereum mainnet |
| `ALCHEMY_NOTIFY_AUTH_TOKEN` | dashboard token so new wallets get added to the webhook |

Webhook URL (unchanged path):

```text
https://<prod-express>/monerium/chain/transfers
```

Filter / contract: Ethereum EURe `0x39b8B6385416f4cA36a20319F70D28621895279D`.

The Flutter listener uses the same RPC + token via dart-define / `.env`:

```text
ALCHEMY_NETWORK_URL=https://eth-mainnet.g.alchemy.com/v2/<key>
MONERIUM_NETWORK_ADDRESS=0x39b8B6385416f4cA36a20319F70D28621895279D
```

`make run-mobile` / `make build-web` already pass those two. Rebuild the app after changing `.env`.

---

## 4. What you can leave

| Piece | Why |
| --- | --- |
| Invoice tables | Settlement matching stays in Express; **prod uses a new Supabase project** (`docs/prod-migration.md`) |
| `wallet.slickbills.com` | Prod wallet (`slickbills-wallet-client-prod`); `VITE_EXPRESS_SERVER_URL` must be prod Express. Staging is `wallet-staging.slickbills.com` |
| Web3Auth client id / network | That’s the **wallet key**, not Monerium. Changing Sapphire network gives users **new addresses** — don’t switch unless you mean to |
| Coinbase CDP / Base EURC | Not on the Monerium pay path |

`wallet-client` Express host is `VITE_EXPRESS_SERVER_URL` (`wallet-client/src/config.ts`). Staging wallet → `express-ten-xi`; prod wallet → prod Express.

---

## 5. Smoke test (real €, two KYC’d prod accounts)

Use €1–2.

1. Connect wallet + Monerium SIWE. IBAN shows. Balance is Ethereum EURe.
2. SEPA into that IBAN → mint → balance in app.
3. A sends invoice to B. B pays. Order `processed`. Invoice **PAID**. Both notified. `moneriumOrderId` / `txHash` stored.
4. Withdraw to an external IBAN.
5. Pay the same IBAN from a normal bank with the invoice reference → still matches.

If 3 fails but the bank/EURe moved, Alchemy webhook or EURe contract address is still sandbox.

---

## 6. Quick verify after deploy

- Express logs / a test SIWE: authorize URL host is `api.monerium.app`, not `api.monerium.dev`
- SIWE log line: `chainId: 1`, `redirectUri` = the portal callback
- Alchemy dashboard: webhook is Ethereum mainnet, last ping hits `/monerium/chain/transfers` with 200
- No leftover Amoy token address in Vercel or Flutter `.env`
