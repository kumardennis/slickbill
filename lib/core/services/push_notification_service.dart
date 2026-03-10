import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  // Use runtime initialization so dotenv and kDebugMode work correctly.
  static late final String _oneSignalAppId = kDebugMode
      ? (dotenv.env['ONESIGNAL_APP_ID'] ?? '')
      : const String.fromEnvironment('ONESIGNAL_APP_ID');

  static late final String _oneSignalRestApiKey = kDebugMode
      ? (dotenv.env['ONESIGNAL_REST_API_KEY'] ?? '')
      : const String.fromEnvironment('ONESIGNAL_REST_API_KEY');

  static bool _isInitialized = false;

  /// Initialize push notifications (call once in main.dart)
  static Future<void> initializeApp() async {
    if (_isInitialized) return;

    try {
      if (_oneSignalAppId.isEmpty) {
        print('❌ ONESIGNAL_APP_ID is empty');
        return;
      }

      print('🔵 Initializing OneSignal app... $_oneSignalAppId');

      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      OneSignal.initialize(_oneSignalAppId);

      final accepted = await OneSignal.Notifications.requestPermission(true);
      print('notif permission accepted: $accepted');
      OneSignal.User.pushSubscription.optIn();

      OneSignal.User.pushSubscription.addObserver((state) {
        print('subscriptionId: ${state.current.id}');
        print('token: ${state.current.token}');
        print('optedIn: ${state.current.optedIn}');
      });

      OneSignal.Notifications.addClickListener((event) {
        final data = event.notification.additionalData;
        _handleNotificationClick(data);
      });

      _isInitialized = true;
      print('✅ OneSignal app initialized');
    } catch (e) {
      print('❌ Error initializing OneSignal: $e');
    }
  }

  /// Login user to OneSignal (call after user logs in)
  static Future<void> loginUser(String userId) async {
    try {
      await initializeApp();

      print('🔵 Logging in user to OneSignal: $userId');

      // ✅ Set external user ID (link OneSignal to your user)
      await OneSignal.login(userId);
      final onsignalId = await OneSignal.User.getOnesignalId();

      print('🔷 OneSignal Player ID: $onsignalId');

      print('✅ User logged in to OneSignal: $userId');
    } catch (e) {
      print('❌ Error logging in user: $e');
    }
  }

  /// Logout user from OneSignal (call when user logs out)
  static Future<void> logoutUser() async {
    try {
      print('🔵 Logging out user from OneSignal...');

      // ✅ Logout from OneSignal
      await OneSignal.logout();

      print('✅ User logged out from OneSignal');
    } catch (e) {
      print('❌ Error logging out user: $e');
    }
  }

  /// Handle notification clicks
  static void _handleNotificationClick(Map<String, dynamic>? data) {
    if (data == null) return;

    final type = data['type'];
    final invoiceId = data['invoice_id'];

    print('🔔 Notification clicked: $type, invoice: $invoiceId');

    switch (type) {
      case 'invoice_claimed':
        Get.toNamed('/public-invoices');
        break;
      case 'invoice_received':
        Get.toNamed('/bill/$invoiceId');
        break;
      case 'payment_reminder':
        Get.toNamed('/bill/$invoiceId');
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
