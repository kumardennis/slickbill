import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:slickbill/feature_dashboard/utils/received_invoices_class.dart';
import 'package:slickbill/shared_screens/received_invoice.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_dashboard/getx_controllers/digital_invoice_controller.dart';
import 'package:slickbill/core/services/invoice_toast_coordinator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  static late final String _oneSignalAppId =
      kDebugMode ? (dotenv.env['ONESIGNAL_APP_ID'] ?? '') : '';

  static late final String _oneSignalRestApiKey =
      kDebugMode ? (dotenv.env['ONESIGNAL_REST_API_KEY'] ?? '') : '';

  static bool _isInitialized = false;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  static StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  static Map<String, dynamic>? _pendingNotificationData;
  static Timer? _tokenFetchRetryTimer;
  static int _tokenFetchRetryAttempt = 0;
  static const int _maxTokenFetchRetryAttempts = 6;

  /// Initialize push notifications (call once in main.dart)
  static Future<void> initializeApp() async {
    if (_isInitialized) return;
    if (Firebase.apps.isEmpty) {
      print(
          '⚠️ Skipping Firebase Messaging because Firebase is not initialized');
      return;
    }

    try {
      print('🔵 Initializing Firebase Messaging...');

      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      print('notif permission: ${settings.authorizationStatus.name}');

      _tokenRefreshSubscription ??=
          FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
        print('🔄 FCM token refreshed');
        await _persistPushToken(token);
      });

      _foregroundMessageSubscription ??=
          FirebaseMessaging.onMessage.listen((message) {
        _handleForegroundMessage(message);
      });

      _messageOpenedSubscription ??=
          FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleRemoteMessageTap(message);
      });

      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _pendingNotificationData =
            Map<String, dynamic>.from(initialMessage.data);
      }

      _isInitialized = true;
      print('✅ Firebase Messaging initialized');
    } catch (e) {
      print('❌ Error initializing Firebase Messaging: $e');
    }
  }

  static bool consumePendingNavigation() {
    final data = _pendingNotificationData;
    if (data == null) return false;

    _pendingNotificationData = null;
    unawaited(_handleNotificationClick(data));
    return true;
  }

  /// Login user for push notifications and persist current FCM token.
  static Future<void> loginUser() async {
    try {
      await initializeApp();
      if (Firebase.apps.isEmpty) {
        return;
      }

      print('🔵 Linking push token to user');

      // Delete the existing token first so Firebase issues a fresh unique
      // token for this login session. Without this, Firebase recycles the
      // previous user's token and they end up sharing it in the database.
      try {
        await FirebaseMessaging.instance.deleteToken();
        print('🗑️ Old FCM token deleted, requesting fresh token');
      } catch (e) {
        if (_isApnsTokenNotSetError(e)) {
          print('⚠️ APNS token not ready yet, skipping old token deletion');
        } else {
          print('⚠️ Could not delete old token: $e');
        }
      }

      final token = await _getFcmTokenSafely();
      if (token == null || token.isEmpty) {
        print('⚠️ FCM token not available');
        _scheduleTokenFetchRetry();
        return;
      }

      _cancelTokenFetchRetry();

      await _persistPushToken(token);

      print('✅ User push token linked: $token');
    } catch (e) {
      print('❌ Error logging in user: $e');
    }
  }

  /// Re-check the current FCM token without forcing a delete/recreate cycle.
  static Future<void> ensureTokenLinked() async {
    try {
      await initializeApp();
      if (Firebase.apps.isEmpty) {
        return;
      }

      final token = await _getFcmTokenSafely();
      if (token == null || token.isEmpty) {
        print('⚠️ FCM token still unavailable during recheck');
        _scheduleTokenFetchRetry();
        return;
      }

      _cancelTokenFetchRetry();
      await _persistPushToken(token);
      print('✅ Existing FCM token linked during resume: $token');
    } catch (e) {
      print('❌ Error ensuring push token is linked: $e');
    }
  }

  /// Logout user from push notifications (call when user logs out)
  static Future<void> logoutUser() async {
    try {
      if (Firebase.apps.isEmpty) {
        return;
      }

      print('🔵 Logging out user from push notifications...');

      _cancelTokenFetchRetry();

      await _persistPushToken(null);
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (e) {
        if (_isApnsTokenNotSetError(e)) {
          print('⚠️ APNS token not ready during logout, skipping token delete');
        } else {
          rethrow;
        }
      }

      print('✅ User logged out from push notifications');
    } catch (e) {
      print('❌ Error logging out user: $e');
    }
  }

  static Future<void> _persistPushToken(String? token) async {
    final client = Supabase.instance.client;

    int? appUserId;
    if (Get.isRegistered<UserController>()) {
      final id = Get.find<UserController>().user.value.id;
      if (id > 0) appUserId = id;
    }

    if (appUserId != null) {
      // Clear this token from any other user on the same device first.
      if (token != null) {
        await client
            .from('users')
            .update({'fcm_token': null})
            .eq('fcm_token', token)
            .neq('id', appUserId);
      }
      await client
          .from('users')
          .update({'fcm_token': token}).eq('id', appUserId);
      print('✅ Updated users.fcm_token for user id: $appUserId');
      return;
    }

    final authUserId = client.auth.currentUser?.id;
    if (authUserId == null) {
      print('⚠️ No auth user found for token persistence');
      return;
    }

    await client
        .from('users')
        .update({'fcm_token': token}).eq('authUserId', authUserId);
    print('✅ Updated users.fcm_token for auth user id');
  }

  static bool _isIosFamily() =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static bool _isApnsTokenNotSetError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('apns-token-not-set') ||
        (text.contains('apns token') &&
            text.contains('not') &&
            text.contains('set'));
  }

  static Future<String?> _getFcmTokenSafely() async {
    if (_isIosFamily()) {
      try {
        final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken == null || apnsToken.isEmpty) {
          print('⚠️ APNS token is not available yet; FCM token fetch deferred');
          return null;
        }
      } catch (e) {
        if (_isApnsTokenNotSetError(e)) {
          print('⚠️ APNS token not set yet; FCM token fetch deferred');
          return null;
        }
        rethrow;
      }
    }

    return FirebaseMessaging.instance.getToken();
  }

  static void _scheduleTokenFetchRetry() {
    if (!_isIosFamily()) return;
    if (_tokenFetchRetryTimer?.isActive == true) return;
    if (_tokenFetchRetryAttempt >= _maxTokenFetchRetryAttempts) return;

    final delaySeconds = 2 << _tokenFetchRetryAttempt;
    _tokenFetchRetryAttempt += 1;

    _tokenFetchRetryTimer = Timer(Duration(seconds: delaySeconds), () async {
      _tokenFetchRetryTimer = null;

      if (Firebase.apps.isEmpty) return;

      try {
        final token = await _getFcmTokenSafely();
        if (token == null || token.isEmpty) {
          print('⚠️ FCM token still unavailable, retrying later');
          _scheduleTokenFetchRetry();
          return;
        }

        _cancelTokenFetchRetry();
        await _persistPushToken(token);
        print('✅ FCM token recovered after retry: $token');
      } catch (e) {
        print('⚠️ Failed to retry FCM token fetch: $e');
        _scheduleTokenFetchRetry();
      }
    });
  }

  static void _cancelTokenFetchRetry() {
    _tokenFetchRetryTimer?.cancel();
    _tokenFetchRetryTimer = null;
    _tokenFetchRetryAttempt = 0;
  }

  static void _handleRemoteMessageTap(RemoteMessage message) {
    if (message.data.isEmpty) return;
    unawaited(
        _handleNotificationClick(Map<String, dynamic>.from(message.data)));
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    final type = data['type'];

    final title = message.notification?.title ?? _foregroundTitleForType(type);
    final body = message.notification?.body ?? _foregroundBodyForType(type);

    if (title == null || body == null) return;

    // Pay flow already shows a local "Payment Initiated" toast.
    if (type == 'SLICKBILL_PROCESSING' ||
        type == 'monerium_payment_processing') {
      return;
    }

    final invoiceId = '${data['invoiceId'] ?? data['invoice_id'] ?? ''}'.trim();
    if (type == 'SLICKBILL_PAID') {
      if (!InvoiceToastCoordinator.claimToast(
        kind: InvoiceToastCoordinator.kindOwnerPaid,
        invoiceId: invoiceId,
      )) {
        return;
      }
    } else if (type == 'SLICKBILL_PAYMENT_SUCCESS') {
      if (!InvoiceToastCoordinator.claimToast(
        kind: InvoiceToastCoordinator.kindPayerPaid,
        invoiceId: invoiceId,
      )) {
        return;
      }
    }

    Get.snackbar(
      title,
      body,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.all(12),
      mainButton: type == 'SLICKBILL_PAYMENT_SUCCESS' || type == 'SLICKBILL_PAID'
          ? TextButton(
              onPressed: () {
                if (Get.isSnackbarOpen) {
                  Get.closeCurrentSnackbar();
                }
                if (!Get.isRegistered<DigitalInvoiceController>()) return;
                final invoices = Get.find<DigitalInvoiceController>();
                if (type == 'SLICKBILL_PAYMENT_SUCCESS') {
                  invoices.requestReceivedListRefresh();
                } else {
                  invoices.requestSentListRefresh();
                }
              },
              child: const Text('Refresh'),
            )
          : null,
    );
  }

  static String? _foregroundTitleForType(dynamic type) {
    switch (type) {
      case 'NEW_SLICKBILL':
      case 'invoice_received':
        return 'New Slickbill';
      case 'SLICKBILL_PAID':
        return 'Slickbill Paid';
      case 'SLICKBILL_PAYMENT_SUCCESS':
        return 'Payment successful';
      case 'SLICKBILL_PROCESSING':
      case 'monerium_payment_processing':
        return 'Payment in process';
      case 'MONERIUM_ACCOUNT_TRANSFER':
        return 'You got money in Slickbills';
      case 'payment_reminder':
        return 'Payment reminder';
      default:
        return null;
    }
  }

  static String? _foregroundBodyForType(dynamic type) {
    switch (type) {
      case 'NEW_SLICKBILL':
      case 'invoice_received':
        return 'A new slickbill has arrived.';
      case 'SLICKBILL_PAID':
        return 'One of your slickbills has been paid.';
      case 'SLICKBILL_PAYMENT_SUCCESS':
        return 'Your slickbill payment went through.';
      case 'SLICKBILL_PROCESSING':
      case 'monerium_payment_processing':
        return 'Your invoice payment is currently processing.';
      case 'MONERIUM_ACCOUNT_TRANSFER':
        return 'You got money in Slickbills.';
      case 'payment_reminder':
        return 'You have an unpaid slickbill waiting.';
      default:
        return null;
    }
  }

  /// Handle notification clicks
  static Future<void> _handleNotificationClick(
      Map<String, dynamic>? data) async {
    if (data == null) return;

    final type = data['type'];
    final invoiceId = data['invoiceId'] ?? data['invoice_id'];

    print('🔔 Notification clicked: $type, invoice: $invoiceId');

    switch (type) {
      case 'NEW_SLICKBILL':
      case 'invoice_received':
      case 'SLICKBILL_PROCESSING':
      case 'monerium_payment_processing':
      case 'payment_reminder':
        final parsedInvoiceId = int.tryParse('$invoiceId');
        if (parsedInvoiceId == null) {
          Get.offAllNamed('/home-screen');
          return;
        }

        final invoices = await ReceivedInvoicesClass()
            .getPrivateReceivedInvoices(id: parsedInvoiceId);
        final invoice = invoices?.isNotEmpty == true ? invoices!.first : null;

        if (invoice == null) {
          Get.offAllNamed('/home-screen');
          return;
        }

        Get.offAllNamed('/home-screen');
        Get.to(() => ReceivedInvoice(invoice: invoice));
        break;
      case 'SLICKBILL_PAID':
      case 'invoice_claimed':
        Get.offAllNamed('/home-screen');
        break;
      default:
        Get.offAllNamed('/home-screen');
        break;
    }
  }

  /// Send notification to a specific user (using external user ID)
  static Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      print('📤 Sending notification to user: $userId');

      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $_oneSignalRestApiKey',
        },
        body: jsonEncode({
          'app_id': _oneSignalAppId,
          // ✅ Use external user ID instead of player ID
          'include_external_user_ids': [userId],
          'headings': {'en': title},
          'contents': {'en': message},
          'data': data ?? {},
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Notification sent to user: $userId');
        print('Response: ${response.body}');
      } else {
        print('❌ Failed to send notification: ${response.statusCode}');
        print('Response: ${response.body}');
      }
    } catch (e) {
      print('❌ Error sending notification: $e');
    }
  }
}
