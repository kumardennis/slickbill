# Production migration

Two stacks. Same git repo. Never mix env, money, or databases.

**Do not change existing Vercel projects, env, or the current Supabase.** Those stay staging.

Work on `master`. Merge `master` → `production` only when staging is good. Do not develop on `production`.

| | Staging — leave as-is (`master`) | Production — create new (`production` branch) |
| --- | --- | --- |
| Supabase | `fwujdruuvspdoqflttrl` | `zgeegkwdcgfwiamjylfg` |
| Express | `express-ten-xi.vercel.app` (`express` project) | `slickbills-express-prod` → https://slickbills-express-prod.vercel.app |
| Wallet | `wallet.slickbills.com` | **new** Vercel project |
| Flutter web | `app-staging.slickbills.com` (`slickbills-app`) | `slickbills-app-prod` → `app.slickbills.com` |
| Monerium | `api.monerium.dev` | `api.monerium.app` |
| Alchemy | test chain | Polygon mainnet |

`APP_ENV=dev` (default, local `.env`) → staging column. `APP_ENV=production` → prod column. Flutter: `lib/config/app_env.dart`.

## Order (prod beside staging)

1. New prod Supabase → apply `supabase/migrations/` + deploy functions. No data copy.
2. `production` git branch. New Express Vercel project, Production Branch = `production`, root `vercel/express`. Prod env only.
3. New wallet-client Vercel project, Production Branch = `production`, root `wallet-client`. `VITE_APP_ENV=production`, `VITE_EXPRESS_SERVER_URL` = new Express.
4. Monerium prod portal + Alchemy webhook on the **new** Express host.
5. `app.slickbills.com` → prod Flutter web (`slickbills-app-prod`). Staging Flutter web is `app-staging.slickbills.com` (`slickbills-app`). Leave `wallet.slickbills.com` on staging until a later wallet cutover.

## Prod database

1. Create the project. Save URL, anon key, service role.
2. Link **without** replacing staging: `supabase link --project-ref <prod-ref>` in a dedicated checkout, or use `--project-ref` on each command.
3. `supabase db push` — every file in `supabase/migrations/`.
4. Deploy `supabase/functions/` to that project.
5. Dashboard: Auth providers, redirect URLs, storage, secrets (`EXPRESS_SERVER_URL` = new Express).

New schema: migration in the repo → staging first → prod after merge to `production`.

## Prod Express env (type from scratch)

Project: `slickbills-express-prod`. Origin: `https://slickbills-express-prod.vercel.app`. Local `vercel/express/.vercel` stays linked to staging `express` — do not relink it.

Already set (Production only): `APP_ENV`, prod `SUPABASE_URL`, `MONERIUM_BASE_URL=https://api.monerium.app`, Polygon EURe, SIWE strings, `MONERIUM_STATE_SECRET`, `PUBLIC_SERVER_URL`, `MONERIUM_REDIRECT_URI`.

Still type in the Vercel project (Production only, not cloned from `express`):

- `SUPABASE_SERVICE_ROLE_KEY` (prod project)
- `MONERIUM_CLIENT_ID` (monerium.app OAuth app). `MONERIUM_CLIENT_SECRET` is optional — PKCE apps only have a Client ID.
- Alchemy Polygon mainnet webhook vars
- `CDP_API_KEY_ID` / `CDP_API_KEY_SECRET` / `CDP_WALLET_SECRET` if Coinbase onramp is needed

Dashboard (git connect failed from CLI): GitHub `kumardennis/slickbill`, Production Branch = `production`, Root Directory = `vercel/express`, Framework = Express, disable Preview Deployments.

Monerium portal redirect: `https://slickbills-express-prod.vercel.app/monerium/oauth/callback`. Then set prod Supabase secret `EXPRESS_SERVER_URL` to the same origin. Checklist: `docs/monerium-prod-cutover.md`.

Local `make run-web` / `make run-mobile` stays staging.
