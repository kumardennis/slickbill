import 'package:slickbill/core/services/push_notification_service.dart';

class NotificationHelper {
  /// Notify invoice claimed
  static Future<void> notifyInvoiceClaimed({
    required String senderUserId, // ✅ Use user ID, not auth user ID
    required double amount,
    required String invoiceId,
  }) async {
    await PushNotificationService.sendNotificationToUser(
      userId: senderUserId, // ✅ OneSignal will target all user's devices
      title: 'Invoice Claimed! 🎉',
      message: 'Someone claimed your €${amount.toStringAsFixed(2)} invoice',
      data: {
        'type': 'invoice_claimed',
        'invoice_id': invoiceId,
      },
    );
  }

  /// Notify invoice received
  static Future<void> notifyInvoiceReceived({
    required String recipientUserId,
    required double amount,
    required String senderName,
    required String invoiceId,
  }) async {
    await PushNotificationService.sendNotificationToUser(
      userId: recipientUserId,
      title: 'New Invoice 📨',
      message: 'You received €${amount.toStringAsFixed(2)} from $senderName',
      data: {
        'type': 'invoice_received',
        'invoice_id': invoiceId,
      },
    );
  }
}
