import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_loyalty/repos/merchant_insights_repo.dart';
import 'package:slickbill/feature_loyalty/screens/merchant_check_in_landing_screen.dart';
import 'package:slickbill/feature_loyalty/screens/merchant_customers_screen.dart';

String? parseCheckoutToken(String rawValue) {
  final join = parseCheckoutJoin(rawValue);
  if (join != null) return join.checkoutToken;

  final trimmed = rawValue.trim();
  if (trimmed.isEmpty) return null;

  if (trimmed.startsWith('https://app.slickbills.com/m/')) {
    final token = trimmed.split('/m/').last.split('?').first.trim();
    return token.isEmpty ? null : token;
  }

  Uri uri;
  try {
    uri = Uri.parse(trimmed);
  } catch (_) {
    return null;
  }

  if (uri.scheme == 'https' || uri.scheme == 'http') {
    if (uri.pathSegments.length >= 4 &&
        uri.pathSegments[0] == 'm' &&
        uri.pathSegments[2] == 'join') {
      final token = uri.pathSegments[1].trim();
      return token.isEmpty ? null : token;
    }
    if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'm') {
      final token = uri.pathSegments[1].trim();
      return token.isEmpty ? null : token;
    }
  }

  if ((uri.scheme == 'slickbills' || uri.scheme == 'slickbill') &&
      uri.host == 'm') {
    final token =
        uri.pathSegments.isNotEmpty ? uri.pathSegments.first.trim() : '';
    return token.isEmpty ? null : token;
  }

  return null;
}

class CheckoutJoinQr {
  final String checkoutToken;
  final String joinCode;

  const CheckoutJoinQr({
    required this.checkoutToken,
    required this.joinCode,
  });
}

CheckoutJoinQr? parseCheckoutJoin(String rawValue) {
  final trimmed = rawValue.trim();
  if (trimmed.isEmpty) return null;

  Uri uri;
  try {
    uri = Uri.parse(trimmed);
  } catch (_) {
    return null;
  }

  if (uri.scheme == 'https' || uri.scheme == 'http') {
    if (uri.pathSegments.length >= 4 &&
        uri.pathSegments[0] == 'm' &&
        uri.pathSegments[2] == 'join') {
      final checkout = uri.pathSegments[1].trim();
      final joinCode = uri.pathSegments[3].trim();
      if (checkout.isNotEmpty && joinCode.isNotEmpty) {
        return CheckoutJoinQr(checkoutToken: checkout, joinCode: joinCode);
      }
    }
  }

  return null;
}

String? parseBillToken(String rawValue) {
  final trimmed = rawValue.trim();
  if (trimmed.isEmpty) return null;

  if (trimmed.startsWith('https://app.slickbills.com/bill/')) {
    final token = trimmed.split('/bill/').last.split('?').first.trim();
    return token.isEmpty ? null : token;
  }

  Uri uri;
  try {
    uri = Uri.parse(trimmed);
  } catch (_) {
    return null;
  }

  if (uri.scheme == 'https' || uri.scheme == 'http') {
    if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'bill') {
      final token = uri.pathSegments[1].trim();
      return token.isEmpty ? null : token;
    }
  }

  if ((uri.scheme == 'slickbills' || uri.scheme == 'slickbill') &&
      uri.host == 'bill') {
    final token =
        uri.pathSegments.isNotEmpty ? uri.pathSegments.first.trim() : '';
    return token.isEmpty ? null : token;
  }

  return null;
}

Future<bool> _isOwnMerchantCheckoutToken(String checkoutToken) async {
  if (!Get.isRegistered<UserController>()) return false;

  final user = Get.find<UserController>().user.value;
  if (!user.isBusiness) return false;

  try {
    final qr = await MerchantInsightsRepo().getCheckoutQr();
    return qr.checkoutToken.trim() == checkoutToken.trim();
  } catch (_) {
    return false;
  }
}

void _openAfterScan(Widget Function() page) {
  SchedulerBinding.instance.addPostFrameCallback((_) {
    Get.to(page);
  });
}

/// Navigate after the scanner route closes so GetX pushes on the app stack.
Future<bool> navigateScannedQrPayload(String rawValue) async {
  final joinQr = parseCheckoutJoin(rawValue);
  if (joinQr != null) {
    _openAfterScan(
      () => MerchantCheckInLandingScreen(
        checkoutToken: joinQr.checkoutToken,
        joinCode: joinQr.joinCode,
      ),
    );
    return true;
  }

  final checkoutToken = parseCheckoutToken(rawValue);
  if (checkoutToken != null) {
    if (await _isOwnMerchantCheckoutToken(checkoutToken)) {
      _openAfterScan(() => const MerchantCustomersScreen());
      return true;
    }

    _openAfterScan(
      () => MerchantCheckInLandingScreen(checkoutToken: checkoutToken),
    );
    return true;
  }

  final billToken = parseBillToken(rawValue);
  if (billToken != null) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      Get.toNamed('/bill/$billToken');
    });
    return true;
  }

  return false;
}

/// @deprecated Use [navigateScannedQrPayload] after the scanner closes.
Future<bool> routeScannedQrPayload(String rawValue) =>
    navigateScannedQrPayload(rawValue);
