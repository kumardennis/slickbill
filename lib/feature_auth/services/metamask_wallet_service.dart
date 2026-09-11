import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:slickbill/feature_auth/getx_controllers/app_lock_controller.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_auth/services/native_web3auth_service.dart';
import 'package:slickbill/shared_widgets/sb_post_message_impl.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class WalletClientCancelledException implements Exception {
  WalletClientCancelledException([this.message = 'Payment cancelled']);
  final String message;

  @override
  String toString() => message;
}

/// Payment summary shown on the wallet-client confirm page.
/// IBAN is masked before it is put in the URL.
class WalletClientPaymentPreview {
  const WalletClientPaymentPreview({
    required this.kind,
    this.amount,
    this.payee,
    this.maskedIban,
    this.reference,
  });

  /// `pay`, `withdraw`, or `link`.
  final String kind;
  final String? amount;
  final String? payee;
  final String? maskedIban;
  final String? reference;

  Map<String, String> toQueryParameters() {
    return {
      'kind': kind,
      if (amount != null && amount!.trim().isNotEmpty) 'amount': amount!.trim(),
      if (payee != null && payee!.trim().isNotEmpty) 'payee': payee!.trim(),
      if (maskedIban != null && maskedIban!.trim().isNotEmpty)
        'iban': maskedIban!.trim(),
      if (reference != null && reference!.trim().isNotEmpty)
        'ref': reference!.trim(),
    };
  }

  static String maskIban(String iban) {
    final compact = iban.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (compact.length < 8) return compact;
    return '${compact.substring(0, 4)} •••• ${compact.substring(compact.length - 4)}';
  }

  static WalletClientPaymentPreview fromOrder(
    Map<String, dynamic> order, {
    required String kind,
  }) {
    var payee = '';
    var iban = '';
    final counterpart = order['counterpart'];
    if (counterpart is Map) {
      final details = counterpart['details'];
      if (details is Map) {
        payee =
            '${details['firstName'] ?? ''} ${details['lastName'] ?? ''}'.trim();
        if (payee.isEmpty) {
          payee = (details['companyName'] ?? details['name'] ?? '')
              .toString()
              .trim();
        }
      }
      final identifier = counterpart['identifier'];
      if (identifier is Map) {
        iban = identifier['iban']?.toString() ?? '';
      }
    }

    return WalletClientPaymentPreview(
      kind: kind,
      amount: order['amount']?.toString(),
      payee: payee.isEmpty ? null : payee,
      maskedIban: iban.isEmpty ? null : maskIban(iban),
      reference: order['referenceNumber']?.toString(),
    );
  }
}

class WebWalletCallback {
  const WebWalletCallback({
    required this.kind,
    required this.completedPendingSign,
    this.address,
    this.signature,
  });

  final String kind;
  final bool completedPendingSign;
  final String? address;
  final String? signature;

  bool get shouldFinishIbanLink =>
      !completedPendingSign &&
      (signature?.isNotEmpty ?? false) &&
      kind != 'pay' &&
      kind != 'withdraw';
}

class MetamaskWalletService {
  // Toggle via --dart-define=WEB3AUTH_MODE=redirect|native (default is redirect)
  static bool useNativeFlow =
      const String.fromEnvironment('WEB3AUTH_MODE', defaultValue: 'redirect')
              .toLowerCase() ==
          'native';

  static void setUseNativeFlow(bool enabled) {
    useNativeFlow = enabled;
  }

  static const String _walletClientBaseUrl = 'https://wallet.slickbills.com';
  static const String _metamaskAuthPath = '/wallet/metamask-auth';
  static const String _callbackHost = 'home-screen';
  static const String moneriumOwnershipMessage =
      'I hereby declare that I am the address owner.';
  static String? _lastConnectedAddress;
  static Completer<String?>? _pendingAuthCompleter;
  static Completer<String>? _pendingSignCompleter;
  static _WalletClientLifecycleObserver? _lifecycleObserver;
  static Timer? _resumeCancelTimer;
  static bool _leftForWalletClient = false;
  static StreamSubscription<Map<String, dynamic>>? _webCallbackSub;

  static String _callbackUriForPlatform({Map<String, String>? extra}) {
    if (kIsWeb) {
      final requestId = DateTime.now().microsecondsSinceEpoch.toString();
      final origin = Uri.base.origin.isNotEmpty
          ? Uri.base.origin
          : 'https://app.slickbills.com';

      return Uri.parse('$origin/home-screen').replace(
        queryParameters: {
          'metamask': '1',
          'request_id': requestId,
          ...?extra,
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
        ...?extra,
      },
    ).toString();
  }

  static void _log(String message) {
    debugPrint('[MetaMaskWebViewFlow] $message');
  }

  static bool isCancelled(Object error) {
    if (error is WalletClientCancelledException) return true;
    final text = error.toString().toLowerCase();
    return text.contains('cancelled') || text.contains('canceled');
  }

  static void _ensureLifecycleWatch() {
    if (_lifecycleObserver != null) return;
    _lifecycleObserver = _WalletClientLifecycleObserver();
    WidgetsBinding.instance.addObserver(_lifecycleObserver!);
  }

  static bool get _hasPendingFlow {
    final sign = _pendingSignCompleter;
    final auth = _pendingAuthCompleter;
    return (sign != null && !sign.isCompleted) ||
        (auth != null && !auth.isCompleted);
  }

  static void _onAppLifecycle(AppLifecycleState state) {
    // On web the wallet client is a separate tab. Hiding this tab is not cancel.
    if (kIsWeb) return;

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (_hasPendingFlow) {
          _leftForWalletClient = true;
        }
        break;
      case AppLifecycleState.resumed:
        if (!_leftForWalletClient || !_hasPendingFlow) {
          return;
        }
        _resumeCancelTimer?.cancel();
        _resumeCancelTimer = Timer(const Duration(milliseconds: 800), () {
          if (!_hasPendingFlow) return;
          _log('wallet-client closed without callback — treating as cancel');
          cancelPendingFlows();
        });
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  static void cancelPendingFlows([String message = 'Payment cancelled']) {
    _resumeCancelTimer?.cancel();
    _resumeCancelTimer = null;
    _leftForWalletClient = false;

    final sign = _pendingSignCompleter;
    if (sign != null && !sign.isCompleted) {
      sign.completeError(WalletClientCancelledException(message));
    }
    _pendingSignCompleter = null;

    final auth = _pendingAuthCompleter;
    if (auth != null && !auth.isCompleted) {
      auth.completeError(WalletClientCancelledException(message));
    }
    _pendingAuthCompleter = null;

    unawaited(_closeWalletTab());
  }

  static void _abortStalePending() {
    _resumeCancelTimer?.cancel();
    _resumeCancelTimer = null;
    _leftForWalletClient = false;

    final sign = _pendingSignCompleter;
    if (sign != null && !sign.isCompleted) {
      sign.completeError(WalletClientCancelledException());
    }
    _pendingSignCompleter = null;

    final auth = _pendingAuthCompleter;
    if (auth != null && !auth.isCompleted) {
      auth.completeError(WalletClientCancelledException());
    }
    _pendingAuthCompleter = null;
    unawaited(_closeWalletTab());
  }

  static Future<void> _closeWalletTab() async {
    try {
      await closeInAppWebView();
    } catch (_) {}
  }

  /// Chrome Custom Tab (Android) / Safari View (iOS). Full Chrome only if that fails.
  static Future<bool> _openWalletClientTab(
    Uri uri, {
    bool replaceCurrentTab = false,
  }) async {
    _ensureLifecycleWatch();

    if (kIsWeb) {
      final opened = slickBillsOpenWalletClientTab(
        uri,
        replaceCurrentTab: replaceCurrentTab,
      );
      if (opened) {
        _log(
          replaceCurrentTab
              ? 'navigating this tab to wallet-client'
              : 'opened wallet-client popup',
        );
        return true;
      }
      return false;
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

  static void _listenForWebWalletCallback() {
    if (!kIsWeb) return;
    _webCallbackSub?.cancel();
    _webCallbackSub = slickBillsPostMessages().listen((msg) {
      final type = msg['type']?.toString();
      if (type != 'SB_METAMASK_AUTH' && type != 'SB_AUTH') return;
      if (type == 'SB_AUTH' && msg['provider']?.toString() != 'metamask') {
        return;
      }

      final success = msg['success'] != false &&
          msg['success']?.toString() != '0' &&
          msg['success']?.toString().toLowerCase() != 'false';
      final address = msg['address']?.toString().trim() ?? '';
      final signature = msg['signature']?.toString().trim() ?? '';
      final flow = msg['flow']?.toString().trim() ?? '';
      final error = msg['error']?.toString().trim() ?? '';

      onAuthCallbackUri(
        Uri.parse('https://app.slickbills.com/home-screen').replace(
          queryParameters: {
            'metamask': '1',
            'success': success ? '1' : '0',
            if (address.isNotEmpty) 'address': address,
            if (signature.isNotEmpty) 'signature': signature,
            if (flow.isNotEmpty) 'flow': flow,
            if (error.isNotEmpty) 'error': error,
          },
        ),
      );
    });
  }

  static void _stopWebWalletCallbackListener() {
    _webCallbackSub?.cancel();
    _webCallbackSub = null;
  }

  /// If the wallet tab had to redirect this tab (no opener), apply the result.
  static Future<WebWalletCallback?> consumeWebCallbackIfPresent() async {
    if (!kIsWeb) return null;

    final uri = Uri.base;
    final isMetaMask = uri.queryParameters['metamask'] == '1';
    if (!isMetaMask) return null;

    final signature = uri.queryParameters['signature']?.trim() ?? '';
    final address = uri.queryParameters['address']?.trim() ?? '';
    final kind = (uri.queryParameters['kind']?.trim().toLowerCase().isNotEmpty ??
            false)
        ? uri.queryParameters['kind']!.trim().toLowerCase()
        : (signature.isNotEmpty ? 'link' : 'connect');
    final hadPendingSign = _pendingSignCompleter != null &&
        !_pendingSignCompleter!.isCompleted;

    onAuthCallbackUri(uri);
    slickBillsBroadcastWalletMessage({
      'type': 'SB_METAMASK_AUTH',
      'provider': 'metamask',
      'success': uri.queryParameters['success'] != '0',
      if (address.isNotEmpty) 'address': address,
      if (signature.isNotEmpty) 'signature': signature,
      if (kind.isNotEmpty) 'kind': kind,
      'flow': signature.isNotEmpty ? 'sign' : 'connect',
    });
    slickBillsClearWalletCallbackQuery();

    if (address.isNotEmpty && Get.isRegistered<UserController>()) {
      final userController = Get.find<UserController>();
      if (userController.user.value.id <= 0) {
        await userController.loadUserData();
      }
      if (userController.user.value.id > 0) {
        await userController.updateMetamaskWalletAddress(address);
      }
    }

    return WebWalletCallback(
      kind: kind,
      completedPendingSign: hadPendingSign,
      address: address.isEmpty ? null : address,
      signature: signature.isEmpty ? null : signature,
    );
  }

  static void onAuthCallbackUri(Uri uri) {
    if (useNativeFlow) {
      NativeWeb3AuthService.onAuthCallbackUri(uri);
      return;
    }

    _resumeCancelTimer?.cancel();
    _resumeCancelTimer = null;
    _leftForWalletClient = false;
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

    _abortStalePending();

    final completer = Completer<String?>();
    _pendingAuthCompleter = completer;

    _listenForWebWalletCallback();

    final authUri =
        Uri.parse('$_walletClientBaseUrl$_metamaskAuthPath').replace(
      queryParameters: {
        'sb': '1',
        'provider': loginProvider,
        'callback_uri': _callbackUriForPlatform(),
      },
    );

    _log('opening wallet connect in custom tab: $authUri');

    AppLockController.beginExternalAuthSession();
    final opened = await _openWalletClientTab(
      authUri,
      replaceCurrentTab: kIsWeb,
    );

    if (!opened) {
      AppLockController.endExternalAuthSession();
      _stopWebWalletCallbackListener();
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
      AppLockController.endExternalAuthSession();
      _stopWebWalletCallbackListener();
      if (identical(_pendingAuthCompleter, completer)) {
        _pendingAuthCompleter = null;
        _leftForWalletClient = false;
      }
    }
  }

  static Future<String> signAddressOwnershipMessage({
    required String address,
    String message = moneriumOwnershipMessage,
    WalletClientPaymentPreview? preview,
  }) async {
    if (useNativeFlow) {
      return NativeWeb3AuthService.signAddressOwnershipMessage(
        address: address,
        message: message,
      );
    }

    _abortStalePending();

    final completer = Completer<String>();
    _pendingSignCompleter = completer;

    _listenForWebWalletCallback();

    final kind = preview?.kind ?? 'link';
    final signUri =
        Uri.parse('$_walletClientBaseUrl$_metamaskAuthPath').replace(
      queryParameters: {
        'sb': '1',
        'mode': 'sign',
        'address': address,
        'sign_message': message,
        'kind': kind,
        'callback_uri': _callbackUriForPlatform(
          extra: {
            'flow': 'sign',
            'kind': kind,
          },
        ),
        ...?preview?.toQueryParameters(),
      },
    );

    _log('opening payment sign in custom tab: $signUri');

    AppLockController.beginExternalAuthSession();
    final opened = await _openWalletClientTab(signUri);

    if (!opened) {
      AppLockController.endExternalAuthSession();
      _stopWebWalletCallbackListener();
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
      AppLockController.endExternalAuthSession();
      _stopWebWalletCallbackListener();
      if (identical(_pendingSignCompleter, completer)) {
        _pendingSignCompleter = null;
        _leftForWalletClient = false;
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

class _WalletClientLifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    MetamaskWalletService._onAppLifecycle(state);
  }
}
