// Web-only implementation.
// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

const _allowedOrigins = <String>{
  'https://wallet.slickbills.com',
  'https://slickbills-wallet-client.vercel.app',
  'http://localhost:53532',
};

const _broadcastChannelName = 'slickbills-wallet';
const _storageCallbackKey = 'sb_wallet_callback';

Map<String, dynamic>? _asStringKeyedMap(dynamic data) {
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }
  if (data is String) {
    final decoded = jsonDecode(data);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  }
  return null;
}

void _emitWalletMessage(
  StreamController<Map<String, dynamic>> controller,
  dynamic data,
) {
  final mapped = _asStringKeyedMap(data);
  if (mapped == null) return;
  controller.add(mapped);
}

Stream<Map<String, dynamic>>? _cachedWalletMessages;

Stream<Map<String, dynamic>> slickBillsPostMessages() {
  return _cachedWalletMessages ??= _createWalletMessageStream();
}

Stream<Map<String, dynamic>> _createWalletMessageStream() {
  final controller = StreamController<Map<String, dynamic>>.broadcast();

  html.window.onMessage.listen((event) {
    try {
      // ignore: avoid_print
      print('postMessage origin=${event.origin} data=${event.data}');

      if (!_allowedOrigins.contains(event.origin)) return;
      _emitWalletMessage(controller, event.data);
    } catch (_) {
      // ignore malformed messages
    }
  });

  try {
    final channel = html.BroadcastChannel(_broadcastChannelName);
    channel.onMessage.listen((event) {
      try {
        _emitWalletMessage(controller, event.data);
      } catch (_) {}
    });
  } catch (_) {
    // BroadcastChannel is unavailable in some older browsers.
  }

  html.window.onStorage.listen((event) {
    if (event.key != _storageCallbackKey) return;
    final value = event.newValue;
    if (value == null || value.isEmpty) return;
    try {
      _emitWalletMessage(controller, event.newValue);
    } catch (_) {}
  });

  return controller.stream;
}

void slickBillsClearWalletCallbackQuery() {
  try {
    final uri = Uri.base;
    final cleaned = uri.replace(query: '');
    html.window.history.replaceState(null, '', cleaned.path);
  } catch (_) {}
}

void slickBillsBroadcastWalletMessage(Map<String, dynamic> payload) {
  try {
    final channel = html.BroadcastChannel(_broadcastChannelName);
    channel.postMessage(payload);
    channel.close();
  } catch (_) {}
}

const _pendingPaymentKey = 'sb_pending_web_payment';

void slickBillsStorePendingWebPayment(Map<String, dynamic> payload) {
  try {
    html.window.localStorage[_pendingPaymentKey] = jsonEncode({
      ...payload,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  } catch (_) {}
}

Map<String, dynamic>? slickBillsTakePendingWebPayment() {
  try {
    final raw = html.window.localStorage[_pendingPaymentKey];
    html.window.localStorage.remove(_pendingPaymentKey);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final mapped = Map<String, dynamic>.from(decoded);
    final ts = mapped['ts'];
    if (ts is int) {
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > const Duration(minutes: 15).inMilliseconds) return null;
    }
    return mapped;
  } catch (_) {
    return null;
  }
}

bool slickBillsOpenWalletClientTab(
  Uri uri, {
  bool replaceCurrentTab = true,
}) {
  try {
    if (replaceCurrentTab) {
      html.window.location.assign(uri.toString());
      return true;
    }

    html.window.open(uri.toString(), '_blank');
    return true;
  } catch (_) {
    return false;
  }
}
