# Tech debt

Living list. Do not start these unless asked. Newest first.

## Security

Implemented: **cold start**, **return to app** (12s grace), **pay-click** on Monerium pay and withdraw. Device PIN fallback. Web skipped. Interactive sign-in does not re-prompt. Fail-closed if the device has no passcode / biometrics.

- **Tokens still in SharedPreferences.** Monerium refresh token is `monerium_session_$userId`. The lock UI does not encrypt tokens. Move to Keychain / Android Keystore (optionally biometric-bound) before calling this done.
- Do **not** prompt on silent refresh, statements, settlement poll, or `hasActiveSession`.

## Dead rails

- **Coinbase pay is unused.** `createCoinbaseTransaction` / `CoinbaseService.transferEURC` still sit in `ReceivedBills`, `received_invoice.dart`, and the received sheet. `MoneriumService` still uses `CoinbaseService.baseUrl` as the Express host (name only). Strip when convenient; CDP onramp on the server may still be a different thing.

## Architecture

- **Payment orchestration lives in list screens.** `ReceivedBills` (and `shared_screens/received_invoice.dart`) still contain Monerium / leftover Coinbase / CDP / SEPA glue, then pass a stack of callbacks into the sheet. List should list; pay recipe should be one caller.
- **Trash is a copy of dashboard.** `feature_trashboard` sheets/utils drift from live invoice sheets. Fixes get done twice.
- **God files.** `MoneriumService` (~1400 lines: OAuth, session, orders, transfer), `received_invoice_sheet.dart` (~1100), `ReceivedBills` (~850). Split when touching them for a real feature.
- **Two UI systems.** `color_scheme.dart` (GetX scheme extensions) vs `theme/sb_colors.dart`. Invoice detail sheets stay navy on purpose; lists should use Stitch tokens. Don’t mix blindly.
- **Two data layers.** Loyalty uses repos + typed models. Invoices still use `*Class` utils next to `DigitalInvoiceRepository`. Prefer repos for new invoice work.
- **Map-fishing APIs.** Monerium responses parsed as `Map<String, dynamic>` in several places. Typed summaries exist server-side (`moneriumOrderSummary.ts`) but the client still guesses keys.

## Hygiene

- Leftover `print` / emoji debug in splash, auth, biometrics, payments.
- Hardcoded copy beside GetX `.tr` keys (`SbQuickRequestCard`).
- Typos in filenames (`spash_screen.dart`, `supabase_auth_manger.dart`).
- `lib/_NFCHandler.dart` at repo root.
- Duplicate `dotenv.load()` in `main.dart`; Supabase URL hardcoded next to `EnvConfig`.
