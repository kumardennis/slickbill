import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:slickbill/feature_dashboard/getx_controllers/digital_invoice_controller.dart';

/// Dedupes settle toasts when FCM, Realtime, and the pay flow all fire.
class InvoiceToastCoordinator {
  InvoiceToastCoordinator._();

  static final Map<String, DateTime> _claimedAt = {};
  static const Duration _window = Duration(seconds: 20);

  static String _key({required String kind, required String invoiceId}) =>
      '$kind:$invoiceId';

  /// Returns true if this source should show the toast (first claim wins).
  static bool claimToast({
    required String kind,
    required String invoiceId,
  }) {
    final id = invoiceId.trim();
    if (id.isEmpty || id == '0') {
      // No invoice id — still allow toast, but don't dedupe blindly.
      return true;
    }

    final key = _key(kind: kind, invoiceId: id);
    final previous = _claimedAt[key];
    final now = DateTime.now();
    if (previous != null && now.difference(previous) < _window) {
      return false;
    }
    _claimedAt[key] = now;
    return true;
  }

  static const String kindOwnerPaid = 'owner_paid';
  static const String kindPayerPaid = 'payer_paid';

  static void notifyPayerPaidInApp({required String invoiceId}) {
    if (!claimToast(kind: kindPayerPaid, invoiceId: invoiceId)) {
      return;
    }
    if (Get.isRegistered<DigitalInvoiceController>()) {
      Get.find<DigitalInvoiceController>().requestReceivedListRefresh();
    }
    Get.snackbar(
      'Payment successful',
      'Your slickbill payment went through.',
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.all(12),
      mainButton: TextButton(
        onPressed: () {
          if (Get.isSnackbarOpen) {
            Get.closeCurrentSnackbar();
          }
          if (Get.isRegistered<DigitalInvoiceController>()) {
            Get.find<DigitalInvoiceController>().requestReceivedListRefresh();
          }
        },
        child: const Text('Refresh'),
      ),
    );
  }
}
