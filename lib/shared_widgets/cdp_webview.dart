import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/shared_widgets/sb_post_message_impl.dart';

enum CdpAutoCloseMode {
  none,
  auth, // close on address OR balance
  balance,
  pay, // close on txHash
  onrampUrl,
}

class CdpWebView extends StatefulWidget {
  final String url;
  final String title;
  final String? accessToken;

  /// Controls which JS values cause the webview to auto-close.
  final CdpAutoCloseMode autoCloseMode;

  const CdpWebView({
    super.key,
    required this.url,
    this.title = 'Loading',
    this.accessToken,
    this.autoCloseMode = CdpAutoCloseMode.none,
  });

  @override
  State<CdpWebView> createState() => _CdpWebViewState();
}

class _CdpWebViewState extends State<CdpWebView> {
  InAppWebViewController? _controller;
  double progress = 0;

  Timer? _pollTimer;
  bool _tokenInjected = false;
  bool _closed = false;
  StreamSubscription<Map<String, dynamic>>? _webMsgSub;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      _webMsgSub = slickBillsPostMessages().listen((msg) async {
        if (_closed) return;

        final type = msg['type'];
        if (type is! String) return;

        Map<String, dynamic> snapshot;

        switch (type) {
          case 'SB_BALANCE':
            final addr = msg['address'];
            final bal = msg['balance'];
            snapshot = <String, dynamic>{
              'success': true,
              if (addr is String && addr.isNotEmpty) 'address': addr,
              if (bal is String && bal.isNotEmpty) 'balance': bal,
            };
            break;

          case 'SB_AUTH':
            final addr = msg['address'];
            final cdpUserId = msg['cdpUserId'];
            snapshot = <String, dynamic>{
              'success': true,
              if (addr is String && addr.isNotEmpty) 'address': addr,
              if (cdpUserId is String && cdpUserId.isNotEmpty)
                'cdpUserId': cdpUserId,
            };
            break;

          case 'SB_PAY':
            final txHash = msg['txHash'];
            snapshot = <String, dynamic>{
              'success': true,
              if (txHash is String && txHash.isNotEmpty) 'txHash': txHash,
            };
            break;

          case 'SB_ONRAMP':
            final onrampUrl = msg['onrampUrl'];
            snapshot = <String, dynamic>{
              'success': true,
              if (onrampUrl is String && onrampUrl.isNotEmpty)
                'onrampUrl': onrampUrl,
            };
            break;

          default:
            return;
        }

        // If we got nothing useful, don't close.
        if (snapshot.length <= 1) return;

        if (_shouldClose(snapshot)) {
          _closeWithResult(snapshot);
        }
      });
    }
  }

  Map<String, dynamic>? _tryDecodeJwtPart(String part) {
    try {
      final normalized = base64Url.normalize(part);
      final bytes = base64Url.decode(normalized);
      return json.decode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static const String exchangeServerBaseUrl =
      'https://express-ten-xi.vercel.app';

  static Future<String> _createExchangeCode(String jwt) async {
    final res = await http.post(
      Uri.parse('$exchangeServerBaseUrl/cdp/exchange-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': jwt}),
    );

    final json = jsonDecode(res.body) as Map<String, dynamic>?;

    if (res.statusCode != 200) {
      throw Exception(
          'exchange-code failed (${res.statusCode}): ${json?['error'] ?? res.body}');
    }

    final code = json?['code'];
    if (code is! String || code.isEmpty) {
      throw Exception('exchange-code returned invalid code');
    }

    return code;
  }

  /// ✅ If running on Flutter Web, append `sb=1&code=...` to the wallet-client URL
  /// so the React app can consume the exchange-code and populate `window.flutterAccessToken`.
  Future<String> _buildInitialUrl() async {
    final base = Uri.parse(widget.url);

    if (!kIsWeb) return base.toString();

    final jwt = widget.accessToken;
    if (jwt == null || jwt.isEmpty) return base.toString();

    final code = await _createExchangeCode(jwt);

    final merged = <String, String>{
      ...base.queryParameters,
      'sb': '1',
      'code': code,
    };

    return base.replace(queryParameters: merged).toString();
  }

  void _logJwtSummary(String jwt) {
    final pieces = jwt.split('.');
    if (pieces.length < 2) {
      // ignore: avoid_print
      print('JWT: invalid format');
      return;
    }

    final header = _tryDecodeJwtPart(pieces[0]);
    final payload = _tryDecodeJwtPart(pieces[1]);

    // ignore: avoid_print
    print(
      'JWT: alg=${header?['alg']} kid=${header?['kid']} iss=${payload?['iss']} aud=${payload?['aud']}',
    );
  }

  @override
  void dispose() {
    _webMsgSub?.cancel();
    _webMsgSub = null;
    _pollTimer?.cancel();
    super.dispose();
  }

  void _closeWithResult(Map<String, dynamic> result) {
    if (_closed) return;
    _closed = true;

    _pollTimer?.cancel();

    try {
      // Try to pop this page regardless; if it can't, it will throw.
      Get.back(result: result);
    } catch (_) {
      // ignore
    }
  }

  String _buildFlutterBootstrapScript() {
    final token = widget.accessToken?.replaceAll("'", r"\'");
    final tokenLine = (token != null && token.isNotEmpty)
        ? "window.flutterAccessToken = '$token';"
        : '';

    return '''
      window.isFlutterApp = true;
      $tokenLine
      console.log('✅ Flutter bootstrap globals ready');
    ''';
  }

  Future<void> _injectFlutterGlobals() async {
    if (_controller == null) return;
    if (_tokenInjected) return;

    if (widget.accessToken != null && widget.accessToken!.isNotEmpty) {
      _logJwtSummary(widget.accessToken!);
    }

    await _controller!
        .evaluateJavascript(source: _buildFlutterBootstrapScript());

    _tokenInjected = true;
  }

  String? _normalizeJsString(dynamic v) {
    if (v == null) return null;

    // webview sometimes returns values like '"0.12"' or '"null"'
    if (v is String) {
      var s = v.trim();
      if (s.isEmpty) return null;

      // strip surrounding quotes if present
      if ((s.startsWith('"') && s.endsWith('"')) ||
          (s.startsWith("'") && s.endsWith("'"))) {
        s = s.substring(1, s.length - 1);
      }

      if (s == 'null' || s == 'undefined') return null;
      return s;
    }

    // If it comes back as num/bool, stringify it.
    if (v is num || v is bool) return v.toString();

    // Last resort: try JSON encode
    try {
      final s = jsonEncode(v);
      if (s == 'null') return null;
      return s;
    } catch (_) {
      return v.toString();
    }
  }

  Future<Map<String, dynamic>> _readWalletSnapshot() async {
    if (_controller == null) return {};

    // Return JSON strings from JS so the transport is consistent.
    final addressRaw = await _controller!.evaluateJavascript(source: '''
      (() => {
        try {
          const v = (window.getAccountAddressOutOfWeb && typeof window.getAccountAddressOutOfWeb === 'function')
            ? window.getAccountAddressOutOfWeb()
            : null;
          return v === undefined ? null : v;
        } catch (e) { return null; }
      })()
    ''');

    print('📡 Reading wallet snapshot from WebView... ${addressRaw}');

    final cdpUserIdRaw = await _controller!.evaluateJavascript(source: '''
      (() => {
        try {
          const v = (window.getUserIdOutOfWeb && typeof window.getUserIdOutOfWeb === 'function')
            ? window.getUserIdOutOfWeb()
            : null;
          return v === undefined ? null : v;
        } catch (e) { return null; }
      })()
    ''');

    final balanceRaw = await _controller!.evaluateJavascript(source: '''
      (() => {
        try {
          const v = (window.getBalanceOutOfWeb && typeof window.getBalanceOutOfWeb === 'function')
            ? window.getBalanceOutOfWeb()
            : null;
          return v === undefined ? null : v;
        } catch (e) { return null; }
      })()
    ''');

    print('📡 Reading wallet snapshot from WebView... ${balanceRaw}');

    final txHashRaw = await _controller!.evaluateJavascript(source: '''
      (() => {
        try {
          const v = (window.getTxHashOutOfWeb && typeof window.getTxHashOutOfWeb === 'function')
            ? window.getTxHashOutOfWeb()
            : null;
          return v === undefined ? null : v;
        } catch (e) { return null; }
      })()
    ''');

    final onrampUrlRaw = await _controller!.evaluateJavascript(source: '''
      (() => {
        try {
          const v = (window.getOnrampUrlOutOfWeb && typeof window.getOnrampUrlOutOfWeb === 'function')
            ? window.getOnrampUrlOutOfWeb()
            : null;
          return v === undefined ? null : v;
        } catch (e) { return null; }
      })()
    ''');

    final address = _normalizeJsString(addressRaw);
    final cdpUserId = _normalizeJsString(cdpUserIdRaw);
    final balance = _normalizeJsString(balanceRaw);
    final txHash = _normalizeJsString(txHashRaw);
    final onrampUrl = _normalizeJsString(onrampUrlRaw);

    return {
      if (address != null) 'address': address,
      if (balance != null) 'balance': balance,
      if (txHash != null) 'txHash': txHash,
      if (cdpUserId != null) 'cdpUserId': cdpUserId,
      if (onrampUrl != null) 'onrampUrl': onrampUrl,
      'success': true,
    };
  }

  bool _isReadyValue(dynamic v) {
    if (v == null) return false;
    if (v is String) return v.trim().isNotEmpty;
    return true;
  }

  bool _shouldClose(Map<String, dynamic> snapshot) {
    switch (widget.autoCloseMode) {
      case CdpAutoCloseMode.none:
        return false;
      case CdpAutoCloseMode.auth:
        return _isReadyValue(snapshot['address']);
      case CdpAutoCloseMode.balance:
        return _isReadyValue(snapshot['balance']);
      case CdpAutoCloseMode.pay:
        return _isReadyValue(snapshot['txHash']);
      case CdpAutoCloseMode.onrampUrl:
        return _isReadyValue(snapshot['onrampUrl']);
    }
  }

  void _startPolling() {
    // ✅ Web should NOT poll. Web closes via postMessage listener.
    if (kIsWeb) return;

    _pollTimer?.cancel();
    if (widget.autoCloseMode == CdpAutoCloseMode.none) return;

    _pollTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) async {
      if (_controller == null || _closed) return;

      final snapshot = await _readWalletSnapshot();

      // ignore: avoid_print
      print('poll snapshot: $snapshot');

      if (_shouldClose(snapshot)) {
        _closeWithResult(snapshot);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _buildInitialUrl(),
      builder: (context, snap) {
        final initialUrl = snap.data;

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.blue,
          appBar: AppBar(
            title: Text(widget.title),
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  if (_closed) return;
                  _closed = true;
                  _pollTimer?.cancel();
                  Get.back(result: {'success': false, 'cancelled': true});
                },
              ),
            ],
          ),
          body: initialUrl == null
              ? const Center(child: CircularProgressIndicator())
              : InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(initialUrl)),
                  initialUserScripts: UnmodifiableListView<UserScript>([
                    UserScript(
                      source: _buildFlutterBootstrapScript(),
                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                      forMainFrameOnly: false,
                    ),
                  ]),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    thirdPartyCookiesEnabled: true,
                    sharedCookiesEnabled: true,
                    allowsInlineMediaPlayback: true,
                    mediaPlaybackRequiresUserGesture: false,
                    transparentBackground: false,
                    useShouldOverrideUrlLoading: true,
                  ),
                  shouldOverrideUrlLoading:
                      (controller, navigationAction) async {
                    final uri = navigationAction.request.url;
                    if (uri == null) return NavigationActionPolicy.ALLOW;

                    final url = uri.toString();

                    // ✅ Block ANY navigation into the parent Flutter app domain
                    // Handles both https://app.slickbills.com/ and https://app.slickbills.com/minified:os
                    if (url.startsWith('https://app.slickbills.com')) {
                      // ignore: avoid_print
                      print('🚫 Blocked navigation into parent app: $url');
                      return NavigationActionPolicy.CANCEL;
                    }

                    return NavigationActionPolicy.ALLOW;
                  },
                  onWebViewCreated: (controller) async {
                    _controller = controller;
                  },
                  onLoadStart: (controller, url) async {
                    if (!kIsWeb) {
                      await _injectFlutterGlobals();
                      _startPolling();
                    }
                  },
                  onLoadStop: (controller, url) async {
                    if (!kIsWeb) {
                      await _injectFlutterGlobals();
                      _startPolling();
                    }
                  },
                  onProgressChanged: (controller, p) {
                    setState(() => progress = p / 100.0);
                  },
                ),
        );
      },
    );
  }
}
