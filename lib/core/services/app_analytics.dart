import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:slickbill/config/app_env.dart';

/// Staging-only product events. No IBAN, names, or amounts.
/// Production builds keep collection off even if this code ships.
class AppAnalytics {
  AppAnalytics._();

  static FirebaseAnalytics? get _fa {
    if (!AppEnv.isDev) return null;
    if (Firebase.apps.isEmpty) return null;
    return FirebaseAnalytics.instance;
  }

  static Future<void> init() async {
    if (Firebase.apps.isEmpty) return;
    final enabled = AppEnv.isDev;
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
    if (!enabled) return;
    await FirebaseAnalytics.instance.setUserProperty(
      name: 'app_env',
      value: AppEnv.name,
    );
  }

  static void identify({
    required int privateUserId,
    required bool isBusiness,
  }) {
    final fa = _fa;
    if (fa == null || privateUserId <= 0) return;
    unawaited(fa.setUserId(id: '$privateUserId'));
    unawaited(fa.setUserProperty(
      name: 'is_business',
      value: isBusiness ? 'true' : 'false',
    ));
  }

  static void reset() {
    final fa = _fa;
    if (fa == null) return;
    unawaited(fa.setUserId(id: null));
  }

  static void signupCompleted({String method = 'email'}) =>
      _log('signup_completed', {'method': method});

  static void bankDetailsSaved() => _log('bank_details_saved');

  static void moneriumConnected() => _log('monerium_connected');

  static void invoiceCreated({required String kind}) =>
      _log('invoice_created', {'kind': kind});

  static void publicInvoiceOpened() => _log('public_invoice_opened');

  static void publicInvoiceClaimed() => _log('public_invoice_claimed');

  static void payStarted({String method = 'monerium'}) =>
      _log('pay_started', {'method': method});

  static void paySucceeded({String method = 'monerium'}) =>
      _log('pay_succeeded', {'method': method});

  static void payFailed({
    String method = 'monerium',
    required String reason,
  }) =>
      _log('pay_failed', {'method': method, 'reason': reason});

  static void pushOpened({String? type}) {
    final trimmed = type?.trim() ?? '';
    if (trimmed.isEmpty) {
      _log('push_opened');
      return;
    }
    _log('push_opened', {'type': trimmed});
  }

  static void _log(String name, [Map<String, Object>? params]) {
    final fa = _fa;
    if (fa == null) return;
    unawaited(fa.logEvent(name: name, parameters: params));
  }
}
