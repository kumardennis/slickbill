import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:slickbill/feature_auth/services/native_web3auth_service.dart';
import 'package:url_launcher/url_launcher.dart';

class MetamaskWalletService {
  // Toggle via --dart-define=WEB3AUTH_MODE=redirect|native (default is redirect)
  static bool useNativeFlow =
      const String.fromEnvironment('WEB3AUTH_MODE', defaultValue: 'redirect')
              .toLowerCase() ==
          'native';

  static void setUseNativeFlow(bool enabled) {
    useNativeFlow = enabled;
  }

  static const String _walletClientBaseUrl =
      'https://slickbills-wallet-client.vercel.app';
  static const String _metamaskAuthPath = '/wallet/metamask-auth';
  static const String _callbackHost = 'home-screen';
  static const String moneriumOwnershipMessage =
      'I hereby declare that I am the address owner.';
  static String? _lastConnectedAddress;
  static Completer<String?>? _pendingAuthCompleter;
  static Completer<String>? _pendingSignCompleter;

  static String _callbackUriForPlatform() {
    if (kIsWeb) {
      final requestId = DateTime.now().microsecondsSinceEpoch.toString();
      final origin = Uri.base.origin.isNotEmpty
          ? Uri.base.origin
          : 'https://app.slickbills.com';

      return Uri.parse('$origin/home-screen').replace(
        queryParameters: {
          'metamask': '1',
          'request_id': requestId,
        },
      ).toString();
    }

    final scheme = defaultTargetPlatform == TargetPlatform.iOS
        ? 'slickbill'
        : 'slickbills';
    final requestId = DateTime.now().microsecondsSinceEpoch.toString();

    return Uri(
      scheme: scheme,
      host: _callbackHost,
      queryParameters: {
        'metamask': '1',
        'request_id': requestId,
      },
    ).toString();
  }

  static void _log(String message) {
    debugPrint('[MetaMaskWebViewFlow] $message');
  }

  static Future<void> _closeWalletTab() async {
    try {
      await closeInAppWebView();
    } catch (_) {}
  }

  /// Chrome Custom Tab (Android) / Safari View (iOS). Full Chrome only if that fails.
  static Future<bool> _openWalletClientTab(Uri uri) async {
    if (kIsWeb) {
      return launchUrl(uri, mode: LaunchMode.platformDefault);
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (opened) {
        _log('opened wallet-client in custom tab');
        return true;
      }
    } catch (error) {
      _log('custom tab failed, falling back to Chrome: $error');
    }

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static void onAuthCallbackUri(Uri uri) {
    if (useNativeFlow) {
      NativeWeb3AuthService.onAuthCallbackUri(uri);
      return;
    }

    unawaited(_closeWalletTab());
    _log('onAuthCallbackUri() received: $uri');

    final flow = uri.queryParameters['flow']?.trim().toLowerCase();
    final signature = uri.queryParameters['signature']?.trim();
    if (flow == 'sign' || (signature != null && signature.isNotEmpty)) {
      final signCompleter = _pendingSignCompleter;
      if (signCompleter == null || signCompleter.isCompleted) {
        _log('onAuthCallbackUri() no pending sign completer');
      } else {
        final successRaw = uri.queryParameters['success'];
        final success = successRaw == null ||
            successRaw == '1' ||
            successRaw.toLowerCase() == 'true';
        final error = uri.queryParameters['error']?.trim();
        final address = uri.queryParameters['address']?.trim();

        if (!success) {
          signCompleter
              .completeError(Exception(error ?? 'MetaMask signing failed'));
        } else if (signature == null || signature.isEmpty) {
          signCompleter
              .completeError(Exception('MetaMask callback missing signature'));
        } else {
          if (address != null && address.isNotEmpty) {
            _lastConnectedAddress = address;
          }
          signCompleter.complete(signature);
        }
      }
      return;
    }

    final completer = _pendingAuthCompleter;
    if (completer == null || completer.isCompleted) {
      _log('onAuthCallbackUri() no pending auth completer');
      return;
    }

    final successRaw = uri.queryParameters['success'];
    final success = successRaw == null ||
        successRaw == '1' ||
        successRaw.toLowerCase() == 'true';
    final address = uri.queryParameters['address']?.trim();
    final error = uri.queryParameters['error']?.trim();

    if (!success) {
      _log('onAuthCallbackUri() auth failed: ${error ?? 'unknown'}');
      completer
          .completeError(Exception(error ?? 'MetaMask authentication failed'));
      return;
    }

    if (address == null || address.isEmpty) {
      _log('onAuthCallbackUri() missing address');
      completer
          .completeError(Exception('MetaMask callback missing wallet address'));
      return;
    }

    _lastConnectedAddress = address;
    completer.complete(address);
  }

  static Future<String?> connectWalletAddress({
    String? accessToken,
    String loginProvider = 'google',
  }) async {
    if (useNativeFlow) {
      return NativeWeb3AuthService.connectWalletAddress(
        accessToken: accessToken,
        loginProvider: loginProvider,
      );
    }

    if (_pendingAuthCompleter != null && !_pendingAuthCompleter!.isCompleted) {
      _log('connectWalletAddress() auth already in progress');
      return _pendingAuthCompleter!.future;
    }

    final completer = Completer<String?>();
    _pendingAuthCompleter = completer;

    final authUri =
        Uri.parse('$_walletClientBaseUrl$_metamaskAuthPath').replace(
      queryParameters: {
        'sb': '1',
        'provider': loginProvider,
        'callback_uri': _callbackUriForPlatform(),
      },
    );

    _log('opening wallet connect in custom tab: $authUri');

    final opened = await _openWalletClientTab(authUri);

    if (!opened) {
      _pendingAuthCompleter = null;
      throw Exception('Unable to open wallet connect');
    }

    try {
      final address = await completer.future.timeout(
        const Duration(minutes: 4),
        onTimeout: () =>
            throw Exception('MetaMask login timed out. Please try again.'),
      );
      _log('connectWalletAddress() received address');
      return address;
    } finally {
      if (identical(_pendingAuthCompleter, completer)) {
        _pendingAuthCompleter = null;
      }
    }
  }

  static Future<String> signAddressOwnershipMessage({
    required String address,
    String message = moneriumOwnershipMessage,
  }) async {
    if (useNativeFlow) {
      return NativeWeb3AuthService.signAddressOwnershipMessage(
        address: address,
        message: message,
      );
    }

    if (_pendingSignCompleter != null && !_pendingSignCompleter!.isCompleted) {
      _log('signAddressOwnershipMessage() signing already in progress');
      return _pendingSignCompleter!.future;
    }

    final completer = Completer<String>();
    _pendingSignCompleter = completer;

    final signUri =
        Uri.parse('$_walletClientBaseUrl$_metamaskAuthPath').replace(
      queryParameters: {
        'sb': '1',
        'mode': 'sign',
        'address': address,
        'sign_message': message,
        'callback_uri': _callbackUriForPlatform(),
      },
    );

    _log('opening payment sign in custom tab: $signUri');

    final opened = await _openWalletClientTab(signUri);

    if (!opened) {
      _pendingSignCompleter = null;
      throw Exception('Unable to open payment signing');
    }

    try {
      final signature = await completer.future.timeout(
        const Duration(minutes: 4),
        onTimeout: () => throw Exception('MetaMask signing timed out.'),
      );
      _log('signAddressOwnershipMessage() received signature');
      return signature;
    } finally {
      if (identical(_pendingSignCompleter, completer)) {
        _pendingSignCompleter = null;
      }
    }
  }

  static Future<String?> getWalletAddress() async {
    if (useNativeFlow) {
      return NativeWeb3AuthService.getWalletAddress();
    }

    _log('getWalletAddress() cached=${_lastConnectedAddress != null}');
    return _lastConnectedAddress;
  }
}
