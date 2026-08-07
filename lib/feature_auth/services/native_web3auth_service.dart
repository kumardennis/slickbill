import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:slickbill/config/env_config.dart';
import 'package:web3auth_flutter/enums.dart';
import 'package:web3auth_flutter/input.dart';
import 'package:web3auth_flutter/output.dart';
import 'package:web3auth_flutter/web3auth_flutter.dart';
import 'package:web3dart/web3dart.dart';

class NativeWeb3AuthService {
  static String? _lastConnectedAddress;
  static String? _lastPrivKey;
  static bool _initialized = false;

  static void _log(String message) {
    debugPrint('[NativeWeb3Auth] $message');
  }

  static Uri _redirectUrlForPlatform() {
    // Android: w3a://com.slickbills.app/auth
    if (defaultTargetPlatform == TargetPlatform.android) {
      return Uri.parse('w3a://com.slickbills.app/auth');
    }

    // iOS (doc style): {bundleId}://auth
    return Uri.parse('com.slickbills.app://auth');
  }

  static Future<void> initialize() async {
    if (_initialized) return;

    final clientId = EnvConfig.web3AuthClientId.trim();
    if (clientId.isEmpty) {
      throw Exception('WEB3AUTH_CLIENT_ID is missing.');
    }

    final redirectUrl = _redirectUrlForPlatform();
    _log('initialize() with redirectUrl=$redirectUrl');

    await Web3AuthFlutter.init(
      Web3AuthOptions(
        clientId: clientId,
        network: Network.sapphire_devnet,
        redirectUrl: redirectUrl,
      ),
    );

    _initialized = true;
  }

  static void onAuthCallbackUri(Uri uri) {
    // Native flow should not rely on browser query params for identity fields.
    _log('onAuthCallbackUri() received: $uri');
    _log(
      'onAuthCallbackUri() scheme=${uri.scheme} host=${uri.host} path=${uri.path} fragment=${uri.fragment}',
    );
    _log('onAuthCallbackUri() query=${uri.query}');
  }

  static Provider _resolveProvider(String provider) {
    switch (provider.trim().toLowerCase()) {
      case 'facebook':
        return Provider.facebook;
      case 'google':
      default:
        return Provider.google;
    }
  }

  static Future<String?> connectWalletAddress({
    String? accessToken,
    String loginProvider = 'google',
  }) async {
    await initialize();
    _log('connectWalletAddress() start provider=$loginProvider');

    // Fast path: use address already cached in this process.
    if (_lastConnectedAddress != null && _lastConnectedAddress!.isNotEmpty) {
      _log('connectWalletAddress() returning cached address');
      return _lastConnectedAddress;
    }

    // Try to restore an existing Web3Auth session before showing login.
    final restoredAddress = await _tryRestoreAddressFromSession();
    if (restoredAddress != null && restoredAddress.isNotEmpty) {
      _log('connectWalletAddress(): restored existing session');
      return restoredAddress;
    }

    _log('connectWalletAddress() invoking Web3AuthFlutter.login()');

    final response = await Web3AuthFlutter.login(
      LoginParams(
        loginProvider: _resolveProvider(loginProvider),
        redirectUrl: _redirectUrlForPlatform(),
      ),
    );

    _log(
      'connectWalletAddress() login returned error=${response.error} hasPrivKey=${response.privKey != null && response.privKey!.trim().isNotEmpty} hasSession=${response.sessionId != null && response.sessionId!.trim().isNotEmpty}',
    );

    if (response.error != null && response.error!.trim().isNotEmpty) {
      throw Exception('Web3Auth login failed: ${response.error}');
    }

    final address = await _extractAddressFromResponse(response);
    if (address == null || address.isEmpty) {
      throw Exception(
          'Web3Auth login succeeded but wallet address is missing.');
    }

    _log('connectWalletAddress(): obtained address');
    return address;
  }

  static Future<String> signAddressOwnershipMessage({
    required String address,
    required String message,
  }) async {
    await initialize();

    final privKey = await _resolvePrivKey();
    if (privKey == null || privKey.isEmpty) {
      throw Exception('No active Web3Auth session available for signing.');
    }

    final credentials = EthPrivateKey.fromHex(privKey);
    final sessionAddress = credentials.address.eip55With0x;

    if (address.trim().isNotEmpty &&
        sessionAddress.toLowerCase() != address.trim().toLowerCase()) {
      throw Exception(
          'Connected Web3Auth account does not match requested wallet address.');
    }

    final payload = Uint8List.fromList(utf8.encode(message));
    final signatureBytes =
        credentials.signPersonalMessageToUint8List(payload, chainId: null);
    final signatureHex = bytesToHex(signatureBytes, include0x: true);
    return signatureHex;
  }

  static Future<String?> getWalletAddress() async {
    if (_lastConnectedAddress != null && _lastConnectedAddress!.isNotEmpty) {
      return _lastConnectedAddress;
    }

    await initialize();
    return _tryRestoreAddressFromSession();
  }

  static Future<String?> _tryRestoreAddressFromSession() async {
    try {
      _log(
          '_tryRestoreAddressFromSession() calling Web3AuthFlutter.initialize()');
      await Web3AuthFlutter.initialize();
      _log('_tryRestoreAddressFromSession() initialize() succeeded');
    } catch (_) {
      // No active session.
      _log('_tryRestoreAddressFromSession() no active session');
      return null;
    }

    final privKey = await _resolvePrivKey();
    if (privKey == null || privKey.isEmpty) {
      _log(
          '_tryRestoreAddressFromSession() initialize succeeded but privKey missing');
      return null;
    }

    final address = _addressFromPrivKey(privKey);
    if (address != null && address.isNotEmpty) {
      _lastPrivKey = privKey;
      _lastConnectedAddress = address;
    }
    return address;
  }

  static Future<String?> _extractAddressFromResponse(
      Web3AuthResponse response) async {
    String? privKey = response.privKey?.trim();
    privKey = _normalizePrivKey(privKey);
    _log(
      '_extractAddressFromResponse() response has direct privKey=${privKey != null && privKey.isNotEmpty}',
    );

    if (privKey == null || privKey.isEmpty) {
      privKey = await _resolvePrivKey();
    }

    if (privKey == null || privKey.isEmpty) {
      _log('_extractAddressFromResponse() no privKey available after fallback');
      return null;
    }

    final address = _addressFromPrivKey(privKey);
    if (address != null && address.isNotEmpty) {
      _lastPrivKey = privKey;
      _lastConnectedAddress = address;
    }
    return address;
  }

  static Future<String?> _resolvePrivKey() async {
    if (_lastPrivKey != null && _lastPrivKey!.isNotEmpty) {
      return _lastPrivKey;
    }

    try {
      final key = _normalizePrivKey(await Web3AuthFlutter.getPrivKey());
      if (key != null && key.isNotEmpty) {
        _lastPrivKey = key;
        return key;
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  static String? _addressFromPrivKey(String privKey) {
    final normalized = _normalizePrivKey(privKey);
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    final credentials = EthPrivateKey.fromHex(normalized);
    return credentials.address.eip55With0x;
  }

  static String? _normalizePrivKey(String? key) {
    if (key == null) return null;
    final trimmed = key.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('0x')) return trimmed;
    return '0x$trimmed';
  }

  static Future<void> logout() async {
    try {
      await Web3AuthFlutter.logout();
    } catch (_) {
      // Ignore logout errors; local cache will still be reset.
    }
    _lastPrivKey = null;
    _lastConnectedAddress = null;
    return;
  }

  static void cacheWalletAddress(String address) {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return;
    _lastConnectedAddress = trimmed;
  }
}
