// Web-only implementation.
// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

Stream<Map<String, dynamic>> slickBillsPostMessages() {
  final controller = StreamController<Map<String, dynamic>>.broadcast();

  const allowedOrigins = <String>{
    // wallet-client (prod)
    'https://slickbills-wallet-client.vercel.app',
    // wallet-client (local dev)
    'http://localhost:53532',
  };

  html.window.onMessage.listen((event) {
    try {
      // ...inside onMessage before filtering...
      // ignore: avoid_print
      print('postMessage origin=${event.origin} data=${event.data}');

      // ✅ accept ONLY messages coming from wallet-client
      if (!allowedOrigins.contains(event.origin)) return;

      final data = event.data;

      if (data is Map) {
        controller.add(Map<String, dynamic>.from(data));
        return;
      }

      if (data is String) {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          controller.add(decoded);
        }
      }
    } catch (_) {
      // ignore malformed messages
    }
  });

  return controller.stream;
}
