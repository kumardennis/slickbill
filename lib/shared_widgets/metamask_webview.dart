import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/shared_widgets/sb_post_message_impl.dart';
import 'package:url_launcher/url_launcher.dart';

class MetamaskWebView extends StatefulWidget {
  final String url;
  final String title;
  final String? accessToken;

  const MetamaskWebView({
    super.key,
    required this.url,
    this.title = 'Connect Wallet',
    this.accessToken,
  });

  @override
  State<MetamaskWebView> createState() => _MetamaskWebViewState();
}

class _MetamaskWebViewState extends State<MetamaskWebView> {
  InAppWebViewController? _controller;
  Timer? _pollTimer;
  bool _closed = false;
  bool _injected = false;
  bool _initReadyLogged = false;
  StreamSubscription<Map<String, dynamic>>? _webMsgSub;

  bool _isExternalScheme(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    return scheme.isNotEmpty &&
        scheme != 'http' &&
        scheme != 'https' &&
        scheme != 'about' &&
        scheme != 'data' &&
        scheme != 'javascript' &&
        scheme != 'file' &&
        scheme != 'chrome';
  }

  Future<void> _openExternalUri(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Failed to open external url: $uri - $e');
    }
  }

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      _webMsgSub = slickBillsPostMessages().listen((msg) {
        if (_closed) return;

        final type = msg['type'];
        final provider = msg['provider'];
        if (type is! String) return;

        final isMetamaskEvent = type == 'SB_METAMASK_AUTH' ||
            (type == 'SB_AUTH' && provider == 'metamask');
        if (!isMetamaskEvent) return;

        final address = msg['address'];
        if (address is String && address.trim().isNotEmpty) {
          _closeWithAddress(address.trim());
        }
      });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _webMsgSub?.cancel();
    super.dispose();
  }

  String _buildBootstrapScript() {
    final token = widget.accessToken?.replaceAll("'", r"\'");
    final tokenLine = (token != null && token.isNotEmpty)
        ? "window.flutterAccessToken = '$token';"
        : '';

    return '''
      window.isFlutterApp = true;
      $tokenLine
      window.flutterWalletProvider = 'metamask';
      console.log('MetaMask WebView bootstrap ready');
    ''';
  }

  Future<void> _injectGlobals() async {
    if (_controller == null || _injected) return;
    await _controller!.evaluateJavascript(source: _buildBootstrapScript());
    _injected = true;
  }

  String? _normalize(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      var v = value.trim();
      if (v.isEmpty || v == 'null' || v == 'undefined') return null;
      if ((v.startsWith('"') && v.endsWith('"')) ||
          (v.startsWith("'") && v.endsWith("'"))) {
        v = v.substring(1, v.length - 1);
      }
      return v.trim().isEmpty ? null : v.trim();
    }
    return value.toString();
  }

  Future<String?> _readAddress() async {
    if (_controller == null) return null;

    final addressRaw = await _controller!.evaluateJavascript(source: '''
      (() => {
        try {
          const fn = window.getMetaMaskAddressOutOfWeb;
          if (typeof fn === 'function') {
            const v = fn();
            if (v !== undefined && v !== null && String(v).trim().length > 0) {
              return v;
            }
          }
        } catch (_) {}
        return null;
      })()
    ''');

    return _normalize(addressRaw);
  }

  Future<String?> _readInitState() async {
    if (_controller == null) return null;

    final stateRaw = await _controller!.evaluateJavascript(source: '''
      (() => {
        try {
          const fn = window.getMetaMaskInitStateOutOfWeb;
          if (typeof fn === 'function') {
            return fn();
          }
        } catch (_) {}
        return null;
      })()
    ''');

    return _normalize(stateRaw);
  }

  Future<String?> _readAuthState() async {
    if (_controller == null) return null;

    final stateRaw = await _controller!.evaluateJavascript(source: '''
      (() => {
        try {
          const fn = window.getMetaMaskAuthStateOutOfWeb;
          if (typeof fn === 'function') {
            return fn();
          }
        } catch (_) {}
        return null;
      })()
    ''');

    return _normalize(stateRaw);
  }

  void _closeWithAddress(String address) {
    if (_closed) return;
    _closed = true;
    _pollTimer?.cancel();
    Get.back(result: <String, dynamic>{
      'success': true,
      'provider': 'metamask',
      'address': address,
    });
  }

  void _startPolling() {
    if (kIsWeb) return;

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) async {
      if (_closed) return;

      final initState = await _readInitState();
      if (!_initReadyLogged && initState == 'ready') {
        _initReadyLogged = true;
        debugPrint('MetaMask WebView init ready');
      }

      final authState = await _readAuthState();
      final address = await _readAddress();

      // Close only after explicit MetaMask auth success, never on CDP fallback values.
      if (authState == 'authenticated' &&
          address != null &&
          address.trim().isNotEmpty) {
        _closeWithAddress(address.trim());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(widget.url)),
        initialUserScripts: UnmodifiableListView<UserScript>([
          UserScript(
            source: _buildBootstrapScript(),
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
            forMainFrameOnly: false,
          ),
        ]),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          thirdPartyCookiesEnabled: true,
          sharedCookiesEnabled: true,
          useShouldOverrideUrlLoading: true,
        ),
        onWebViewCreated: (controller) async {
          _controller = controller;
        },
        onLoadStart: (controller, url) async {
          await _injectGlobals();
          _startPolling();
        },
        onLoadStop: (controller, url) async {
          await _injectGlobals();
          _startPolling();
        },
        shouldOverrideUrlLoading: (controller, navigationAction) async {
          final uri = navigationAction.request.url?.uriValue;
          if (uri == null) {
            return NavigationActionPolicy.ALLOW;
          }

          if (_isExternalScheme(uri)) {
            await _openExternalUri(uri);
            return NavigationActionPolicy.CANCEL;
          }

          return NavigationActionPolicy.ALLOW;
        },
      ),
    );
  }
}
