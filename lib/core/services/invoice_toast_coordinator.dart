/// Dedupes settle toasts when FCM and Realtime both fire for the same invoice.
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
}
