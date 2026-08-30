import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:slickbill/feature_auth/services/metamask_wallet_service.dart';
import 'package:slickbill/feature_auth/services/monerium_service.dart';
import 'package:slickbill/shared_utils/scanned_qr_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String? _pendingBillToken;

String? consumePendingBillToken() {
  final token = _pendingBillToken;
  _pendingBillToken = null;
  return token;
}

bool hasPendingBillToken() {
  return (_pendingBillToken?.isNotEmpty ?? false);
}

String? _extractBillToken(Uri uri) {
  if (uri.pathSegments.isNotEmpty && uri.pathSegments.first.trim().isNotEmpty) {
    return uri.pathSegments.first.trim();
  }

  if (uri.fragment.isNotEmpty) {
    final fragment = uri.fragment.trim();
    if (fragment.isNotEmpty) {
      final normalizedFragment =
          fragment.startsWith('/') ? fragment.substring(1) : fragment;
      final fragmentSegments = normalizedFragment
          .split('/')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (fragmentSegments.isNotEmpty) {
        if (fragmentSegments.first == 'bill' && fragmentSegments.length > 1) {
          return fragmentSegments[1];
        }
        if (fragmentSegments.first != 'bill') {
          return fragmentSegments.first;
        }
      }
    }
  }

  final tokenFromQuery = uri.queryParameters['token'] ??
      uri.queryParameters['publicToken'] ??
      uri.queryParameters['invoice_token'];

  if (tokenFromQuery != null && tokenFromQuery.trim().isNotEmpty) {
    return tokenFromQuery.trim();
  }

  return null;
}

String? _extractMerchantCheckoutToken(Uri uri) {
  if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'm') {
    final token = uri.pathSegments[1].trim();
    if (token.isNotEmpty) return token;
  }

  if (uri.pathSegments.isNotEmpty && uri.pathSegments.first.trim().isNotEmpty) {
    return uri.pathSegments.first.trim();
  }

  return null;
}

bool processIncomingDeepLinkUri(Uri uri) {
  if (uri.scheme == 'w3a') {
    print('🔑 Web3Auth callback received');
    print(
        '🔑 Web3Auth callback scheme=${uri.scheme} host=${uri.host} path=${uri.path}');
    print('🔑 Web3Auth callback query=${uri.query}');
    MetamaskWalletService.onAuthCallbackUri(uri);
    return true;
  }

  final isMetaMaskCallback =
      (uri.scheme == 'slickbills' || uri.scheme == 'slickbill') &&
          uri.host == 'metamask-auth';
  if (isMetaMaskCallback) {
    print('🦊 MetaMask callback received');
    print(
        '🦊 MetaMask callback scheme=${uri.scheme} host=${uri.host} path=${uri.path}');
    print('🦊 MetaMask callback query=${uri.query}');
    MetamaskWalletService.onAuthCallbackUri(uri);
    return true;
  }

  final isBillLink =
      (uri.scheme == 'slickbills' || uri.scheme == 'slickbill') &&
          uri.host == 'bill';
  if (isBillLink) {
    print('📄 Bill deep link detected');

    final invoiceToken = _extractBillToken(uri);

    if (invoiceToken != null) {
      print('   Invoice token: $invoiceToken');
      _pendingBillToken = invoiceToken;
      Get.offAllNamed('/bill/$invoiceToken');
    } else {
      print('   No invoice token found in bill deep link, not navigating away');
    }
    return true;
  }

  final isMerchantCheckInLink =
      (uri.scheme == 'slickbills' || uri.scheme == 'slickbill') &&
          uri.host == 'm';
  if (isMerchantCheckInLink) {
    print('🏪 Merchant check-in deep link detected');
    final checkoutToken = _extractMerchantCheckoutToken(uri);
    if (checkoutToken != null) {
      print('   Checkout token: $checkoutToken');
      unawaited(
        navigateScannedQrPayload('https://app.slickbills.com/m/$checkoutToken'),
      );
    }
    return true;
  }

  if (uri.scheme == 'https' &&
      (uri.host == 'app.slickbills.com' ||
          uri.host == 'slickbills.com' ||
          uri.host == 'www.slickbills.com')) {
    if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'm') {
      final checkoutToken = uri.pathSegments[1].trim();
      if (checkoutToken.isNotEmpty) {
        print('🏪 Merchant check-in web link: $checkoutToken');
        unawaited(
          navigateScannedQrPayload(
            'https://app.slickbills.com/m/$checkoutToken',
          ),
        );
        return true;
      }
    }

    if (uri.pathSegments.isNotEmpty) {
      print('🌐 Web deep link: /${uri.pathSegments.join('/')}');
      Get.toNamed('/${uri.pathSegments.join('/')}');
    }
    return true;
  }

  if ((uri.scheme == 'slickbills' || uri.scheme == 'slickbill') &&
      uri.host == 'home-screen') {
    final isMoneriumFlow = uri.queryParameters['monerium'] == '1' ||
        uri.queryParameters['provider'] == 'monerium';

    if (isMoneriumFlow) {
      print('💶 Monerium callback received via home-screen');
      MoneriumService.onAuthCallbackUri(uri);
      return true;
    }

    final isMetaMaskFlow = uri.queryParameters['metamask'] == '1' ||
        uri.queryParameters.containsKey('address') ||
        uri.queryParameters.containsKey('success');

    if (isMetaMaskFlow) {
      print('🦊 MetaMask callback received via home-screen');
      print('🦊 home-screen callback query=${uri.query}');
      MetamaskWalletService.onAuthCallbackUri(uri);
      return true;
    }

    print('🔵 Facebook OAuth callback detected');

    Future.delayed(Duration(milliseconds: 500), () {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        print('✅ OAuth session established');
      } else {
        print('⚠️ No session found after OAuth callback');
      }
    });

    return true;
  }

  return false;
}

void deepLinkHandler(BuildContext context) {
  final appLinks = AppLinks();
  String? lastProcessedLink;
  DateTime? lastProcessedAt;

  appLinks.uriLinkStream.listen((Uri? uri) {
    if (uri != null) {
      print('🔗 Received deep link: $uri');
      final uriString = uri.toString();
      // Prevent near-simultaneous duplicate delivery from the OS/plugin,
      // but allow later attempts even if callback URL repeats.
      final now = DateTime.now();
      final isImmediateDuplicate = lastProcessedLink == uriString &&
          lastProcessedAt != null &&
          now.difference(lastProcessedAt!).inSeconds < 2;

      if (isImmediateDuplicate) {
        print('⏭️ Skipping duplicate deep link: $uriString');
        return;
      }

      void markProcessed() {
        lastProcessedLink = uriString;
        lastProcessedAt = now;
      }

      final handled = processIncomingDeepLinkUri(uri);
      if (handled) {
        markProcessed();
      }
    }
  }, onError: (err) {
    print('❌ Error receiving deep link: $err');
  });
}
