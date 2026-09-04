import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:slickbill/feature_auth/services/app_callback_in_app_browser.dart';
import 'package:slickbill/feature_auth/services/metamask_wallet_service.dart';
import 'package:slickbill/services/coinbase/coinbase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class MoneriumService {
  static Completer<Map<String, dynamic>>? _pendingOAuthCompleter;
  static Future<Map<String, dynamic>>? _pendingConnectFuture;
  static String? _lastOAuthStatus;
  static String? _lastOAuthMessage;
  static String _sessionKey(String userId) => 'monerium_session_$userId';
  static String _addressLinkedKey(String userId) =>
      'monerium_address_linked_$userId';
  static String _balanceConfirmedKey(String userId) =>
      'monerium_balance_confirmed_$userId';
  static String _invoiceOrderKey(int invoiceId) =>
      'monerium_invoice_order_$invoiceId';
  static const String _configuredWalletChain =
      String.fromEnvironment('MONERIUM_WALLET_CHAIN', defaultValue: '');
  static const String _walletClientBaseUrl =
      'https://slickbills-wallet-client.vercel.app';
  static const String _walletSiwePath = '/wallet/siwe';

  static String get _serverBaseUrl => CoinbaseService.baseUrl;

  static void _log(String message) {
    debugPrint('[MoneriumService] $message');
  }

  static bool _isSessionExpiringSoon(Map<String, dynamic>? session) {
    if (session == null) {
      return true;
    }

    final rawExpiresAt = session['expiresAt'];
    final expiresAtMs = rawExpiresAt is int
        ? rawExpiresAt
        : int.tryParse(rawExpiresAt?.toString() ?? '');

    if (expiresAtMs == null || expiresAtMs <= 0) {
      return true;
    }

    const skewMs = 30 * 1000;
    return expiresAtMs - DateTime.now().millisecondsSinceEpoch <= skewMs;
  }

  static bool _isReauthRequired(Object error) {
    final text = error.toString().toUpperCase();
    return text.contains('MONERIUM_REAUTH_REQUIRED') ||
        text.contains('INVALID_GRANT');
  }

  static final Map<String, Future<Map<String, dynamic>?>> _refreshInFlight = {};

  static Future<Map<String, dynamic>?> _sessionFromRefreshResponse({
    required String userId,
    required Map<String, dynamic> refreshed,
    Map<String, dynamic>? previous,
  }) async {
    final data = refreshed['data'];
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final accessToken = data['accessToken']?.toString().trim() ?? '';
    if (accessToken.isEmpty) {
      return null;
    }

    final session = {
      ...?previous,
      'userId': userId,
      'accessToken': accessToken,
      if (data['refreshToken'] != null)
        'refreshToken': data['refreshToken'].toString(),
      if (data['expiresAt'] != null)
        'expiresAt': data['expiresAt'] is int
            ? data['expiresAt']
            : int.tryParse(data['expiresAt'].toString()),
    };
    await _saveSession(session);
    return session;
  }

  static Future<Map<String, dynamic>?> _ensureActiveSession(
      String userId) async {
    final inflight = _refreshInFlight[userId];
    if (inflight != null) {
      return inflight;
    }

    final future = () async {
      final session = await _loadSession(userId);
      if (_hasUsableAccessToken(session)) {
        return session;
      }

      try {
        _log(
            '_ensureActiveSession(): refreshing session for userId=$userId (local=${session != null})');
        final refreshed = await _postJson(
          '/monerium/oauth/refresh',
          body: {
            'userId': userId,
          },
        );
        final saved = await _sessionFromRefreshResponse(
          userId: userId,
          refreshed: refreshed,
          previous: session,
        );
        if (_hasUsableAccessToken(saved)) {
          return saved;
        }
      } catch (error) {
        _log(
            '_ensureActiveSession(): refresh failed for userId=$userId: $error');
        if (_isReauthRequired(error)) {
          await clearStoredSession(userId: userId);
        }
      }

      return null;
    }();

    _refreshInFlight[userId] = future;
    try {
      return await future;
    } finally {
      if (identical(_refreshInFlight[userId], future)) {
        _refreshInFlight.remove(userId);
      }
    }
  }

  static Future<void> _saveSession(Map<String, dynamic> session) async {
    final userId = session['userId']?.toString().trim() ?? '';
    if (userId.isEmpty) {
      _log('_saveSession(): missing userId — session not persisted');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey(userId), jsonEncode(session));
    _log(
        'Saved Monerium session for userId=$userId: hasAccessToken=${session['accessToken'] != null}, hasRefreshToken=${session['refreshToken'] != null}, expiresAt=${session['expiresAt']}');
  }

  static Future<Map<String, dynamic>?> _loadSession(String userId) async {
    if (userId.trim().isEmpty) {
      _log('_loadSession(): missing userId — returning null');
      return null;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey(userId));
    if (raw == null || raw.isEmpty) {
      _log('No stored Monerium session found for userId=$userId');
      return null;
    }

    try {
      final session = jsonDecode(raw) as Map<String, dynamic>;
      _log(
          'Loaded Monerium session for userId=$userId: hasAccessToken=${session['accessToken'] != null}, hasRefreshToken=${session['refreshToken'] != null}, expiresAt=${session['expiresAt']}');
      return session;
    } catch (_) {
      _log('Failed to decode stored Monerium session for userId=$userId');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getStoredSession(
          {required String userId}) =>
      _loadSession(userId);

  static bool _hasUsableAccessToken(Map<String, dynamic>? session) {
    if (session == null) {
      return false;
    }

    final accessToken = session['accessToken']?.toString().trim() ?? '';
    if (accessToken.isEmpty) {
      return false;
    }

    return !_isSessionExpiringSoon(session);
  }

  static Future<void> clearStoredSession({required String userId}) async {
    if (userId.trim().isEmpty) {
      _log('clearStoredSession(): missing userId');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey(userId));
    _log('Cleared stored Monerium session for userId=$userId');
  }

  static Future<void> setAddressLinked({
    required String userId,
    required bool linked,
  }) async {
    if (userId.trim().isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (linked) {
      await prefs.setBool(_addressLinkedKey(userId), true);
    } else {
      await prefs.remove(_addressLinkedKey(userId));
    }
  }

  static Future<bool> isAddressLinkedFlag({required String userId}) async {
    if (userId.trim().isEmpty) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_addressLinkedKey(userId)) ?? false;
  }

  static Future<void> setBalanceConfirmed({
    required String userId,
    required bool confirmed,
  }) async {
    if (userId.trim().isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (confirmed) {
      await prefs.setBool(_balanceConfirmedKey(userId), true);
    } else {
      await prefs.remove(_balanceConfirmedKey(userId));
    }
  }

  static Future<bool> isBalanceConfirmedFlag({required String userId}) async {
    if (userId.trim().isEmpty) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_balanceConfirmedKey(userId)) ?? false;
  }

  static Future<bool> hasActiveSession({required String userId}) async {
    final session = await _ensureActiveSession(userId);
    return _hasUsableAccessToken(session);
  }

  /// Restores a session from the server when possible, otherwise starts OAuth.
  static Future<Map<String, dynamic>> ensureConnected({
    required String userId,
    required String email,
    VoidCallback? onWillOpenLogin,
  }) async {
    final local = await _ensureActiveSession(userId);
    if (_hasUsableAccessToken(local)) {
      return local!;
    }

    _log('ensureConnected(): starting Monerium OAuth for userId=$userId');
    onWillOpenLogin?.call();
    return connect(userId: userId, email: email);
  }

  static AppCallbackInAppBrowser? _authBrowser;

  static Future<void> _closeAuthTab() async {
    try {
      await _authBrowser?.close();
    } catch (_) {}
    _authBrowser = null;
    try {
      await closeInAppWebView();
    } catch (_) {}
  }

  static Future<bool> _openAuthTab(Uri uri) async {
    if (kIsWeb) {
      return launchUrl(uri, mode: LaunchMode.platformDefault);
    }

    // iOS SFSafariViewController (url_launcher custom tab) does not return
    // custom-scheme callbacks like slickbill://, so the sheet never closes.
    // Intercept those URLs in WKWebView and dismiss the browser ourselves.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _authBrowser = AppCallbackInAppBrowser(
        onCallback: (callbackUri) {
          onAuthCallbackUri(callbackUri);
        },
        onClosedWithoutCallback: () {
          final completer = _pendingOAuthCompleter;
          if (completer != null && !completer.isCompleted) {
            completer.completeError(
              Exception('Monerium connect was cancelled.'),
            );
          }
        },
      );
      await AppCallbackInAppBrowser.open(uri, _authBrowser!);
      _log('opened Monerium auth in in-app browser');
      return true;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (opened) {
        _log('opened Monerium auth in custom tab');
        return true;
      }
    } catch (error) {
      _log('custom tab failed, falling back to browser: $error');
    }

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static String _callbackUriForPlatform() {
    if (kIsWeb) {
      final origin = Uri.base.origin.isNotEmpty
          ? Uri.base.origin
          : 'https://app.slickbills.com';
      return Uri.parse('$origin/home-screen').replace(
        queryParameters: {'monerium': '1'},
      ).toString();
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'slickbill://home-screen?monerium=1';
    }
    return 'slickbills://home-screen?monerium=1';
  }

  static Future<Map<String, dynamic>> connect({
    required String userId,
    required String email,
    String? walletAddress,
    String? redirectUri,
    String? appRedirectUri,
    bool forceLogin = false,
  }) async {
    if (_pendingConnectFuture != null) {
      _log('connect() auth already in progress; awaiting existing flow');
      return _pendingConnectFuture!;
    }

    final connectFuture = (() async {
      final completer = Completer<Map<String, dynamic>>();
      _pendingOAuthCompleter = completer;

      try {
        if (!forceLogin) {
          final activeSession = await _ensureActiveSession(userId);
          if (_hasUsableAccessToken(activeSession)) {
            _log(
                'connect() using active Monerium session for userId=$userId (no SIWE/OAuth needed)');
            _lastOAuthStatus = 'success';
            _lastOAuthMessage = null;
            return {
              ...?activeSession,
              'status': 'success',
              'userId': userId,
            };
          }
        } else {
          await clearStoredSession(userId: userId);
        }

        final normalizedWalletAddress = walletAddress?.trim() ?? '';
        if (normalizedWalletAddress.isNotEmpty) {
          final callbackUri = appRedirectUri ?? _callbackUriForPlatform();
          final siweUri =
              Uri.parse('$_walletClientBaseUrl$_walletSiwePath').replace(
            queryParameters: {
              'userId': userId,
              'address': normalizedWalletAddress,
              'app_redirect_uri': callbackUri,
            },
          );

          _log('Opening Monerium SIWE flow');
          final opened = await _openAuthTab(siweUri);

          if (!opened) {
            throw Exception('Unable to open Monerium SIWE URL.');
          }

          final callbackResult = await completer.future.timeout(
            const Duration(minutes: 5),
            onTimeout: () => throw Exception('Monerium SIWE login timed out.'),
          );

          final callbackStatus = callbackResult['status']?.toString();
          if (callbackStatus != 'success') {
            final message = callbackResult['message']?.toString();
            throw Exception(message ?? 'Monerium SIWE failed.');
          }

          final accessToken = callbackResult['accessToken']?.toString();
          if (accessToken != null && accessToken.isNotEmpty) {
            await _saveSession({
              ...callbackResult,
              'userId': userId,
              'accessToken': accessToken,
              if (callbackResult['refreshToken'] != null)
                'refreshToken': callbackResult['refreshToken'].toString(),
              if (callbackResult['expiresAt'] != null)
                'expiresAt': callbackResult['expiresAt'] is int
                    ? callbackResult['expiresAt']
                    : int.tryParse(callbackResult['expiresAt'].toString()),
            });
          }

          _lastOAuthStatus = 'success';
          _lastOAuthMessage = null;
          return callbackResult;
        }

        final startResponse = await _postJson(
          '/monerium/oauth/start',
          body: {
            'userId': userId,
            'email': email,
            'redirectUri': redirectUri,
            'appRedirectUri': appRedirectUri ?? _callbackUriForPlatform(),
            'appAutoRedirect': true,
            'forceLogin': forceLogin,
          },
        );

        final authUrl = (startResponse['data']
            as Map<String, dynamic>?)?['authUrl'] as String?;
        final resolvedRedirectUri = (startResponse['data']
            as Map<String, dynamic>?)?['redirectUri'] as String?;

        if (resolvedRedirectUri != null && resolvedRedirectUri.isNotEmpty) {
          _log('Using OAuth redirect URI: $resolvedRedirectUri');
        }

        if (authUrl == null || authUrl.isEmpty) {
          throw Exception('Monerium auth URL missing from backend response.');
        }

        _log('Opening Monerium OAuth');
        final opened = await _openAuthTab(Uri.parse(authUrl));

        if (!opened) {
          throw Exception('Unable to open Monerium OAuth URL.');
        }

        final callbackResult = await completer.future.timeout(
          const Duration(minutes: 5),
          onTimeout: () => throw Exception('Monerium OAuth login timed out.'),
        );

        final callbackStatus = callbackResult['status']?.toString();
        if (callbackStatus != 'success') {
          final message = callbackResult['message']?.toString();
          throw Exception(message ?? 'Monerium OAuth failed.');
        }

        final accessToken = callbackResult['accessToken']?.toString();
        if (accessToken != null && accessToken.isNotEmpty) {
          await _saveSession({
            ...callbackResult,
            'userId': userId,
            'accessToken': accessToken,
            if (callbackResult['refreshToken'] != null)
              'refreshToken': callbackResult['refreshToken'].toString(),
            if (callbackResult['expiresAt'] != null)
              'expiresAt': callbackResult['expiresAt'] is int
                  ? callbackResult['expiresAt']
                  : int.tryParse(callbackResult['expiresAt'].toString()),
          });
        }

        _lastOAuthStatus = 'success';
        _lastOAuthMessage = null;
        return callbackResult;
      } finally {
        if (identical(_pendingOAuthCompleter, completer)) {
          _pendingOAuthCompleter = null;
        }
        _pendingConnectFuture = null;
      }
    })();

    _pendingConnectFuture = connectFuture;
    return connectFuture;
  }

  static void onAuthCallbackUri(Uri uri) {
    final isMoneriumFlow = uri.queryParameters['monerium'] == '1' ||
        uri.queryParameters['provider'] == 'monerium';

    if (!isMoneriumFlow) {
      return;
    }

    _log('onAuthCallbackUri() received: $uri');
    unawaited(_closeAuthTab());

    final completer = _pendingOAuthCompleter;
    if (completer == null || completer.isCompleted) {
      _log('onAuthCallbackUri() no pending oauth completer');
      return;
    }

    final status = uri.queryParameters['status']?.trim() ?? 'error';
    final message = uri.queryParameters['message']?.trim();
    _lastOAuthStatus = status;
    _lastOAuthMessage = message;

    if (status == 'success') {
      final session = {
        'status': status,
        'message': message,
        'provider': uri.queryParameters['provider'],
        'userId': uri.queryParameters['userId'],
        'accessToken': uri.queryParameters['accessToken'],
        'refreshToken': uri.queryParameters['refreshToken'],
        'expiresAt': int.tryParse(uri.queryParameters['expiresAt'] ?? ''),
      };

      final accessToken = session['accessToken']?.toString();
      if (accessToken != null && accessToken.isNotEmpty) {
        _log('OAuth callback includes token data; persisting session');
        unawaited(_saveSession(session));
      } else {
        _log('OAuth callback missing access token in deep link');
      }

      completer.complete(session);
      return;
    }

    completer.completeError(Exception(message ?? 'Monerium OAuth failed.'));
  }

  static Future<Map<String, dynamic>> getOAuthStatus({
    required String userId,
  }) {
    return _getJson(
      '/monerium/oauth/status',
      query: {'userId': userId},
    );
  }

  static Future<Map<String, dynamic>> refreshToken({
    required String userId,
  }) {
    return _postJson(
      '/monerium/oauth/refresh',
      body: {'userId': userId},
    );
  }

  static String _walletRegisteredKey(String userId, String walletAddress) =>
      'monerium_wallet_registered_${userId}_${walletAddress.toLowerCase()}';

  static Future<void> registerWalletForTracking({
    required String userId,
    required String walletAddress,
  }) async {
    final address = walletAddress.trim();
    if (userId.trim().isEmpty || userId == '0' || address.isEmpty) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _walletRegisteredKey(userId, address);
      if (prefs.getBool(key) == true) {
        return;
      }

      await _ensureActiveSession(userId);
      final result = await _postJson(
        '/monerium/wallet/register',
        body: {
          'userId': userId,
          'walletAddress': address,
        },
      );
      if (result['ok'] == true) {
        await prefs.setBool(key, true);
        _log('registerWalletForTracking(): registered $address for $userId');
      } else {
        _log('registerWalletForTracking(): server returned ${result['data']}');
      }
    } catch (error) {
      _log('registerWalletForTracking() failed: $error');
    }
  }

  static Future<Map<String, dynamic>> linkWallet({
    required String userId,
    required String address,
    String? chain,
    String? profile,
    required String message,
    required String signature,
  }) async {
    final session = await _ensureActiveSession(userId);
    _log(
        'linkWallet(): sessionReady=${_hasUsableAccessToken(session)} for userId=$userId');
    final resolvedChain = (chain != null && chain.trim().isNotEmpty)
        ? chain
        : _configuredWalletChain;
    final resolvedProfile = (profile != null && profile.trim().isNotEmpty)
        ? profile.trim()
        : session?['moneriumProfile']?.toString().trim();
    final response = await _postJson(
      '/monerium/wallet/link',
      body: {
        'userId': userId,
        if (resolvedProfile != null && resolvedProfile.isNotEmpty)
          'profile': resolvedProfile,
        'address': address,
        if (resolvedChain.trim().isNotEmpty) 'chain': resolvedChain,
        'message': message,
        'signature': signature,
      },
    );

    final matchedEntry = response['matchedEntry'];
    final matchedProfile = matchedEntry is Map<String, dynamic>
        ? matchedEntry['profile']?.toString().trim()
        : null;

    if (matchedProfile != null && matchedProfile.isNotEmpty) {
      final nextSession = {
        ...?session,
        'userId': userId,
        'moneriumProfile': matchedProfile,
      };
      await _saveSession(nextSession);
      _log('linkWallet(): persisted matched Monerium profile $matchedProfile');
    }

    return response;
  }

  static Future<Map<String, dynamic>> getIbans({
    required String userId,
  }) async {
    final session = await _ensureActiveSession(userId);
    _log(
        'getIbans(): sessionReady=${_hasUsableAccessToken(session)} for userId=$userId');
    return _getJson(
      '/monerium/ibans',
      query: {
        'userId': userId,
      },
    );
  }

  static Future<Map<String, dynamic>> requestIban({
    required String userId,
    required String address,
    String? chain,
  }) async {
    final session = await _ensureActiveSession(userId);
    final resolvedChain = (chain != null && chain.trim().isNotEmpty)
        ? chain
        : _configuredWalletChain;

    _log(
        'requestIban(): sessionReady=${_hasUsableAccessToken(session)} for userId=$userId');

    return _postJson(
      '/monerium/ibans/request',
      body: {
        'userId': userId,
        'address': address,
        if (resolvedChain.trim().isNotEmpty) 'chain': resolvedChain,
      },
    );
  }

  static Future<Map<String, dynamic>> getBalances({
    required String userId,
    required String address,
    String? chain,
    String? currency,
  }) async {
    final session = await _ensureActiveSession(userId);
    final resolvedChain = (chain != null && chain.trim().isNotEmpty)
        ? chain.trim()
        : _configuredWalletChain;
    final resolvedCurrency =
        (currency != null && currency.trim().isNotEmpty) ? currency.trim() : '';

    _log(
        'getBalances(): sessionReady=${_hasUsableAccessToken(session)} for userId=$userId');

    return _getJson(
      '/monerium/balances',
      query: {
        'userId': userId,
        'address': address,
        if (resolvedChain.isNotEmpty) 'chain': resolvedChain,
        if (resolvedCurrency.isNotEmpty) 'currency': resolvedCurrency,
      },
    );
  }

  static Future<Map<String, dynamic>> getLinkedAddresses({
    required String userId,
    String? address,
  }) async {
    final session = await _ensureActiveSession(userId);
    _log(
        'getLinkedAddresses(): sessionReady=${_hasUsableAccessToken(session)} for userId=$userId');
    return _getJson(
      '/monerium/wallet/addresses',
      query: {
        'userId': userId,
        if (address != null && address.trim().isNotEmpty)
          'address': address.trim(),
      },
    );
  }

  static Future<Map<String, dynamic>> getProfileStatus({
    required String userId,
    String? profile,
  }) async {
    final session = await _ensureActiveSession(userId);
    _log(
        'getProfileStatus(): sessionReady=${_hasUsableAccessToken(session)} for userId=$userId');

    return _getJson(
      '/monerium/profile',
      query: {
        'userId': userId,
        if (profile != null && profile.trim().isNotEmpty) 'profile': profile,
      },
    );
  }

  static Future<Map<String, dynamic>> createRedeemOrder({
    required String userId,
    required dynamic amount,
    String currency = 'EUR',
    required String destinationIban,
    String? recipientName,
    String? reference,
    String? walletAddress,
  }) async {
    await _ensureActiveSession(userId);
    return _postJson(
      '/monerium/orders/redeem',
      body: {
        'userId': userId,
        'amount': amount,
        'currency': currency,
        'destinationIban': destinationIban,
        'recipientName': recipientName,
        'reference': reference,
        'walletAddress': walletAddress,
      },
    );
  }

  static Future<Map<String, dynamic>> getOrder({
    required String userId,
    required String orderId,
  }) async {
    final session = await _ensureActiveSession(userId);
    _log(
        'getOrder(): sessionReady=${_hasUsableAccessToken(session)} for userId=$userId');

    return _getJson(
      '/monerium/orders/$orderId',
      query: {
        'userId': userId,
      },
    );
  }

  static Future<Map<String, dynamic>> getOrders({
    required String userId,
    String? txHash,
    String? state,
    String? kind,
    String? chain,
    String? address,
    String? profile,
  }) async {
    final session = await _ensureActiveSession(userId);
    _log(
        'getOrders(): sessionReady=${_hasUsableAccessToken(session)} for userId=$userId');

    return _getJson(
      '/monerium/orders',
      query: {
        'userId': userId,
        if (txHash != null && txHash.trim().isNotEmpty) 'txHash': txHash.trim(),
        if (state != null && state.trim().isNotEmpty) 'state': state.trim(),
        if (kind != null && kind.trim().isNotEmpty) 'kind': kind.trim(),
        if (chain != null && chain.trim().isNotEmpty) 'chain': chain.trim(),
        if (address != null && address.trim().isNotEmpty)
          'address': address.trim(),
        if (profile != null && profile.trim().isNotEmpty)
          'profile': profile.trim(),
      },
    );
  }

  static String? extractOrderId(Map<String, dynamic>? payload) {
    if (payload == null) {
      return null;
    }

    final data = payload['data'];
    final map = data is Map<String, dynamic> ? data : payload;
    final value = map['id'] ?? map['orderId'] ?? map['uuid'];
    final id = value?.toString().trim();
    return (id == null || id.isEmpty) ? null : id;
  }

  static String? extractOrderState(Map<String, dynamic>? payload) {
    if (payload == null) {
      return null;
    }

    final data = payload['data'];
    final map = data is Map<String, dynamic> ? data : payload;
    final value = map['state']?.toString().trim().toLowerCase();
    return (value == null || value.isEmpty) ? null : value;
  }

  static String? extractOrderTxHash(Map<String, dynamic>? payload) {
    if (payload == null) {
      return null;
    }

    String? readFirstHashFromList(dynamic hashes) {
      if (hashes is! List) {
        return null;
      }

      for (final hash in hashes) {
        if (hash is String) {
          final next = hash.trim();
          if (next.isNotEmpty) {
            return next;
          }
          continue;
        }

        if (hash is Map<String, dynamic>) {
          final next = (hash['txHash'] ?? hash['hash'] ?? hash['tx_hash'])
              ?.toString()
              .trim();
          if (next != null && next.isNotEmpty) {
            return next;
          }
        }
      }

      return null;
    }

    String? readFromOrderMap(Map<String, dynamic> map) {
      final txHashTopLevel =
          (map['txHash'] ?? map['tx_hash'])?.toString().trim();
      if (txHashTopLevel != null && txHashTopLevel.isNotEmpty) {
        return txHashTopLevel;
      }

      final meta = map['meta'];
      if (meta is Map<String, dynamic>) {
        final fromMetaArray =
            readFirstHashFromList(meta['txHashes'] ?? meta['tx_hashes']);
        if (fromMetaArray != null) {
          return fromMetaArray;
        }

        final fromMetaTxs = readFirstHashFromList(meta['txs']);
        if (fromMetaTxs != null) {
          return fromMetaTxs;
        }
      }

      final fromTopTxs = readFirstHashFromList(map['txs']);
      if (fromTopTxs != null) {
        return fromTopTxs;
      }

      return null;
    }

    final candidates = <Map<String, dynamic>>[];
    final data = payload['data'];

    if (data is Map<String, dynamic>) {
      candidates.add(data);

      final nestedOrder = data['order'];
      if (nestedOrder is Map<String, dynamic>) {
        candidates.add(nestedOrder);
      }
    }

    candidates.add(payload);

    final nestedPayloadOrder = payload['order'];
    if (nestedPayloadOrder is Map<String, dynamic>) {
      candidates.add(nestedPayloadOrder);
    }

    for (final candidate in candidates) {
      final found = readFromOrderMap(candidate);
      if (found != null && found.isNotEmpty) {
        return found;
      }
    }

    return null;
  }

  static Future<Map<String, dynamic>> monitorOrderUntilFinal({
    required String userId,
    required String orderId,
    Duration timeout = const Duration(minutes: 2),
    Duration pollInterval = const Duration(seconds: 4),
  }) async {
    final startedAt = DateTime.now();
    Map<String, dynamic>? lastOrder;

    while (DateTime.now().difference(startedAt) < timeout) {
      final response = await getOrder(userId: userId, orderId: orderId);
      final data = response['data'];
      final order = data is Map<String, dynamic> ? data : response;
      lastOrder = order;

      final state = extractOrderState(order);
      final isFinal = state == 'processed' || state == 'rejected';
      if (isFinal) {
        return {
          'final': true,
          'state': state,
          'order': order,
          'orderId': extractOrderId(order) ?? orderId,
          'txHash': extractOrderTxHash(order),
        };
      }

      await Future.delayed(pollInterval);
    }

    return {
      'final': false,
      'state': extractOrderState(lastOrder),
      'order': lastOrder,
      'orderId': extractOrderId(lastOrder) ?? orderId,
      'txHash': extractOrderTxHash(lastOrder),
      'timedOut': true,
    };
  }

  static Map<String, dynamic>? extractFirstOrderFromOrdersResponse(
    Map<String, dynamic>? response,
  ) {
    if (response == null) {
      return null;
    }

    final directData = response['data'];
    if (directData is List &&
        directData.isNotEmpty &&
        directData.first is Map) {
      return Map<String, dynamic>.from(directData.first as Map);
    }

    if (directData is Map<String, dynamic>) {
      final nestedCandidates = [
        directData['items'],
        directData['results'],
        directData['orders'],
        directData['data'],
      ];

      for (final candidate in nestedCandidates) {
        if (candidate is List &&
            candidate.isNotEmpty &&
            candidate.first is Map) {
          return Map<String, dynamic>.from(candidate.first as Map);
        }
      }

      if (directData.containsKey('state') &&
          directData.containsKey('kind') &&
          directData.containsKey('id')) {
        return directData;
      }
    }

    final topCandidates = [
      response['items'],
      response['results'],
      response['orders'],
    ];

    for (final candidate in topCandidates) {
      if (candidate is List && candidate.isNotEmpty && candidate.first is Map) {
        return Map<String, dynamic>.from(candidate.first as Map);
      }
    }

    final firstOrder = response['firstOrder'];
    if (firstOrder is Map<String, dynamic>) {
      return firstOrder;
    }

    return null;
  }

  static List<Map<String, dynamic>> extractOrdersList(
    Map<String, dynamic>? response,
  ) {
    if (response == null) {
      return const [];
    }

    List<dynamic>? list;
    final data = response['data'];
    if (data is List) {
      list = data;
    } else if (data is Map<String, dynamic>) {
      for (final key in ['orders', 'items', 'results', 'data']) {
        final nested = data[key];
        if (nested is List) {
          list = nested;
          break;
        }
      }
      if (list == null && data['id'] != null) {
        list = [data];
      }
    }

    list ??= response['orders'] is List
        ? response['orders'] as List
        : response['items'] is List
            ? response['items'] as List
            : response['results'] is List
                ? response['results'] as List
                : null;

    if (list == null || list.isEmpty) {
      final first = response['firstOrder'];
      if (first is Map) {
        return [Map<String, dynamic>.from(first)];
      }
      return const [];
    }

    return list
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  static Future<Map<String, dynamic>> recheckOrderByTxHash({
    required String userId,
    required String txHash,
  }) async {
    final response = await getOrders(userId: userId, txHash: txHash);
    final order = extractFirstOrderFromOrdersResponse(response);
    final state = extractOrderState(order);

    return {
      'state': state,
      'order': order,
      'orderId': extractOrderId(order),
      'txHash': extractOrderTxHash(order) ?? txHash,
      'found': order != null,
      'response': response,
    };
  }

  static Future<void> savePendingOrderForInvoice({
    required int invoiceId,
    required String orderId,
  }) async {
    if (invoiceId <= 0 || orderId.trim().isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_invoiceOrderKey(invoiceId), orderId.trim());
  }

  static Future<String?> getPendingOrderForInvoice({
    required int invoiceId,
  }) async {
    if (invoiceId <= 0) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final orderId = prefs.getString(_invoiceOrderKey(invoiceId));
    if (orderId == null || orderId.trim().isEmpty) {
      return null;
    }
    return orderId.trim();
  }

  static Future<void> clearPendingOrderForInvoice({
    required int invoiceId,
  }) async {
    if (invoiceId <= 0) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_invoiceOrderKey(invoiceId));
  }

  static Future<Map<String, dynamic>> recheckOrderById({
    required String userId,
    required String orderId,
  }) async {
    final response = await getOrder(userId: userId, orderId: orderId);
    final data = response['data'];
    final order = data is Map<String, dynamic> ? data : response;
    final state = extractOrderState(order);

    return {
      'state': state,
      'order': order,
      'orderId': extractOrderId(order) ?? orderId,
      'txHash': extractOrderTxHash(order),
      'found': order.isNotEmpty,
      'response': response,
    };
  }

  static Future<Map<String, dynamic>> createSendMoneyOrder({
    required String userId,
    required Map<String, dynamic> order,
    String? invoiceId,
  }) async {
    final session = await _ensureActiveSession(userId);

    _log(
        'createSendMoneyOrder(): sessionReady=${_hasUsableAccessToken(session)} for userId=$userId');

    return _postJson(
      '/monerium/orders/send',
      body: {
        'userId': userId,
        'order': order,
        if (invoiceId != null && invoiceId.trim().isNotEmpty)
          'invoiceId': invoiceId.trim(),
      },
    );
  }

  static Future<Map<String, dynamic>> createSendMoneyOrderWithSignature({
    required String userId,
    required String walletAddress,
    required Map<String, dynamic> order,
    String? invoiceId,
  }) async {
    await _ensureActiveSession(userId);

    final resolvedMessage =
        (order['message']?.toString().trim().isNotEmpty ?? false)
            ? order['message'].toString().trim()
            : MetamaskWalletService.moneriumOwnershipMessage;

    final signature = await MetamaskWalletService.signAddressOwnershipMessage(
      address: walletAddress,
      message: resolvedMessage,
    );

    final signedOrder = <String, dynamic>{
      ...order,
      'message': resolvedMessage,
      'signature': signature,
    };

    if (signedOrder['address'] == null ||
        signedOrder['address'].toString().trim().isEmpty) {
      signedOrder['address'] = walletAddress;
    }

    return createSendMoneyOrder(
      userId: userId,
      order: signedOrder,
      invoiceId: invoiceId,
    );
  }

  static Future<Map<String, dynamic>> createWithdrawOrder({
    required String userId,
    required Map<String, dynamic> order,
  }) async {
    final session = await _ensureActiveSession(userId);
    _log(
        'createWithdrawOrder(): sessionReady=${_hasUsableAccessToken(session)} for userId=$userId');

    return _postJson(
      '/monerium/orders/withdraw',
      body: {
        'userId': userId,
        'order': order,
      },
    );
  }

  static Future<Map<String, dynamic>> createWithdrawOrderWithSignature({
    required String userId,
    required String walletAddress,
    required Map<String, dynamic> order,
  }) async {
    await _ensureActiveSession(userId);

    final resolvedMessage =
        (order['message']?.toString().trim().isNotEmpty ?? false)
            ? order['message'].toString().trim()
            : MetamaskWalletService.moneriumOwnershipMessage;

    final signature = await MetamaskWalletService.signAddressOwnershipMessage(
      address: walletAddress,
      message: resolvedMessage,
    );

    final signedOrder = <String, dynamic>{
      ...order,
      'message': resolvedMessage,
      'signature': signature,
    };

    if (signedOrder['address'] == null ||
        signedOrder['address'].toString().trim().isEmpty) {
      signedOrder['address'] = walletAddress;
    }

    return createWithdrawOrder(
      userId: userId,
      order: signedOrder,
    );
  }

  static String? get lastOAuthStatus => _lastOAuthStatus;
  static String? get lastOAuthMessage => _lastOAuthMessage;

  static List<dynamic> extractIbans(dynamic rawData) {
    if (rawData is List) {
      return rawData;
    }

    if (rawData is Map<String, dynamic>) {
      final candidates = [
        rawData['ibans'],
        rawData['items'],
        rawData['results'],
        rawData['data'],
      ];

      for (final candidate in candidates) {
        if (candidate is List) {
          return candidate;
        }
      }
    }

    return const [];
  }

  static List<dynamic> extractIbansFromResponse(Map<String, dynamic> response) {
    final ibans = extractIbans(response['data']);
    if (ibans.isNotEmpty) {
      return ibans;
    }

    final firstIbanRow = response['firstIbanRow'];
    if (firstIbanRow != null) {
      return [firstIbanRow];
    }

    return const [];
  }

  static Future<Map<String, dynamic>> _postJson(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final response = await http.post(
      Uri.parse('$_serverBaseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    return _decodeResponse(response, path);
  }

  static Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$_serverBaseUrl$path').replace(
      queryParameters: query,
    );

    final response = await http.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    );

    return _decodeResponse(response, path);
  }

  static Map<String, dynamic> _decodeResponse(
    http.Response response,
    String path,
  ) {
    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Invalid JSON from $path: ${response.body}');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final error = decoded['error'];
    if (error is Map<String, dynamic>) {
      final code = error['code']?.toString();
      final message = error['message']?.toString();
      final details = error['details'];

      String? detailMessage;
      if (details is Map<String, dynamic>) {
        final data = details['data'];
        if (data is Map<String, dynamic>) {
          detailMessage = data['message']?.toString() ??
              data['error_description']?.toString() ??
              data['detail']?.toString() ??
              data['title']?.toString();

          final validationErrors = data['errors'];
          if (validationErrors != null) {
            final serializedErrors = validationErrors is String
                ? validationErrors
                : jsonEncode(validationErrors);
            if (serializedErrors.isNotEmpty) {
              detailMessage = [
                if (detailMessage != null && detailMessage.isNotEmpty)
                  detailMessage,
                'errors: $serializedErrors',
              ].join(' | ');
            }
          }

          if ((detailMessage == null || detailMessage.isEmpty) &&
              data['error'] is Map<String, dynamic>) {
            final nested = data['error'] as Map<String, dynamic>;
            detailMessage = nested['message']?.toString() ??
                nested['error_description']?.toString() ??
                nested['detail']?.toString() ??
                nested['title']?.toString();
          }
        }
      }

      final composedMessage = [
        message,
        if (detailMessage != null && detailMessage.isNotEmpty) detailMessage,
      ].whereType<String>().join(' | ');

      throw Exception(
          '${code ?? 'MONERIUM_ERROR'}: ${composedMessage.isNotEmpty ? composedMessage : response.body}');
    }

    throw Exception(
        'Request failed ($path): ${response.statusCode} ${response.body}');
  }
}
