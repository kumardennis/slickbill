import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

/// WKWebView / Android WebView that can intercept `slickbill(s)://` returns.
/// Safari View Controller and Chrome Custom Tabs do not hand those schemes back.
class AppCallbackInAppBrowser extends InAppBrowser {
  AppCallbackInAppBrowser({
    required this.onCallback,
    required this.onClosedWithoutCallback,
  });

  final void Function(Uri uri) onCallback;
  final VoidCallback onClosedWithoutCallback;
  bool _callbackHandled = false;

  static bool isAppCallbackUri(Uri? url) {
    if (url == null) {
      return false;
    }
    final scheme = url.scheme.toLowerCase();
    return scheme == 'slickbill' || scheme == 'slickbills';
  }

  static Future<void> open(Uri uri, AppCallbackInAppBrowser browser) {
    return browser.openUrlRequest(
      urlRequest: URLRequest(url: WebUri(uri.toString())),
      settings: InAppBrowserClassSettings(
        browserSettings: InAppBrowserSettings(
          hideUrlBar: true,
          hideToolbarTop: false,
          presentationStyle: ModalPresentationStyle.FULL_SCREEN,
        ),
        webViewSettings: InAppWebViewSettings(
          useShouldOverrideUrlLoading: true,
          javaScriptEnabled: true,
          javaScriptCanOpenWindowsAutomatically: true,
          thirdPartyCookiesEnabled: true,
          sharedCookiesEnabled: true,
        ),
      ),
    );
  }

  Future<void> takeCallback(Uri url) async {
    if (_callbackHandled) {
      return;
    }
    _callbackHandled = true;
    try {
      await close();
    } catch (_) {}
    onCallback(url);
  }

  Future<NavigationActionPolicy> _policyFor(Uri? url) async {
    if (isAppCallbackUri(url)) {
      await takeCallback(url!);
      return NavigationActionPolicy.CANCEL;
    }

    final scheme = url?.scheme.toLowerCase() ?? '';
    if (scheme.isNotEmpty &&
        scheme != 'http' &&
        scheme != 'https' &&
        scheme != 'about' &&
        scheme != 'data' &&
        scheme != 'blob' &&
        scheme != 'file') {
      try {
        await launchUrl(url!, mode: LaunchMode.externalApplication);
      } catch (_) {}
      return NavigationActionPolicy.CANCEL;
    }

    return NavigationActionPolicy.ALLOW;
  }

  @override
  Future<NavigationActionPolicy?> shouldOverrideUrlLoading(
    NavigationAction navigationAction,
  ) async {
    return _policyFor(navigationAction.request.url);
  }

  @override
  void onLoadStart(WebUri? url) {
    if (isAppCallbackUri(url)) {
      unawaited(takeCallback(url!));
    }
  }

  @override
  void onReceivedError(WebResourceRequest request, WebResourceError error) {
    final url = request.url;
    if (isAppCallbackUri(url)) {
      unawaited(takeCallback(url));
    }
  }

  @override
  void onExit() {
    if (!_callbackHandled) {
      onClosedWithoutCallback();
    }
  }
}
