import 'package:slickbill/shared_utils/epc_qr.dart';

import '../models/invoice_model.dart';

/// Same-sender in-app batch pay: one Monerium redeem for selected unpaid bills.
class BatchPayFromSender {
  static bool isUnpaid(InvoiceModel invoice) =>
      invoice.status.trim().toUpperCase() == 'UNPAID';

  static String? normalizedPayIban(InvoiceModel invoice) {
    return EpcQrPayload.normalizeIban(invoice.bankPayIban) ??
        _compactIban(invoice.bankPayIban);
  }

  static int? senderId(InvoiceModel invoice) {
    final fromColumn = invoice.senderPrivateUserId;
    if (fromColumn != null && fromColumn > 0) return fromColumn;
    final fromSender = invoice.senders?.privateUserId;
    if (fromSender != null && fromSender > 0) return fromSender;
    final fromProfile = invoice.senders?.privateUsers?.id;
    if (fromProfile != null && fromProfile > 0) return fromProfile;
    return null;
  }

  /// Shown on the invoice sheet when this bill can start a same-sender picker.
  static bool canOfferPicker(InvoiceModel invoice) {
    return isUnpaid(invoice) &&
        senderId(invoice) != null &&
        normalizedPayIban(invoice) != null;
  }

  static bool samePayRail(InvoiceModel a, InvoiceModel b) {
    final senderA = senderId(a);
    final senderB = senderId(b);
    if (senderA == null || senderB == null || senderA != senderB) {
      return false;
    }
    final ibanA = normalizedPayIban(a);
    final ibanB = normalizedPayIban(b);
    return ibanA != null && ibanB != null && ibanA == ibanB;
  }

  static List<InvoiceModel> eligibleWithSeed({
    required InvoiceModel seed,
    required List<InvoiceModel> candidates,
  }) {
    final byId = <int, InvoiceModel>{};
    if (canOfferPicker(seed)) {
      byId[seed.id] = seed;
    }
    for (final invoice in candidates) {
      if (!isUnpaid(invoice) || !samePayRail(seed, invoice)) continue;
      byId[invoice.id] = invoice;
    }
    final rows = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  static double sum(Iterable<InvoiceModel> invoices) =>
      invoices.fold<double>(0, (total, invoice) => total + invoice.amount);

  /// Returns a GetX locale key, or null when the selection is valid.
  static String? selectionError(List<InvoiceModel> selected) {
    if (selected.isEmpty) return 'err_BatchSelectAtLeastOne';
    final seed = selected.first;
    for (final invoice in selected) {
      if (!isUnpaid(invoice)) {
        return 'err_BatchOnlyUnpaid';
      }
      if (!samePayRail(seed, invoice)) {
        return 'err_BatchSameSenderIban';
      }
    }
    return null;
  }

  static String? _compactIban(String? raw) {
    final compact = (raw ?? '').replaceAll(RegExp(r'\s+'), '').toUpperCase();
    return compact.isEmpty ? null : compact;
  }
}
