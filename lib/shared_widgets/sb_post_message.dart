import 'dart:async';

/// Cross-platform message stream coming from wallet-client (React) iframe/tab.
///
/// On non-web platforms this is an empty stream.
Stream<Map<String, dynamic>> slickBillsPostMessages() =>
    const Stream.empty();

/// Drops wallet-callback query params from the current web URL.
void slickBillsClearWalletCallbackQuery() {}

void slickBillsBroadcastWalletMessage(Map<String, dynamic> payload) {}

void slickBillsStorePendingWebPayment(Map<String, dynamic> payload) {}

Map<String, dynamic>? slickBillsTakePendingWebPayment() => null;

/// Opens the wallet-client. Returns false on non-web platforms so callers
/// can use [launchUrl].
///
/// [replaceCurrentTab] is used for connect: a new tab would boot a fresh
/// Flutter app with an empty user. Sign/pay keeps a popup so the invoice
/// screen can receive the signature.
bool slickBillsOpenWalletClientTab(
  Uri uri, {
  bool replaceCurrentTab = true,
}) =>
    false;