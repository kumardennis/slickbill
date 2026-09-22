/// EPC069-12 SEPA Credit Transfer QR (BCD, version 002).
///
/// Structured remittance (line 10) is always empty. Invoice numbers and
/// `[sb:id]` are not ISO 11649 RF creditor references — putting them there
/// makes Estonian banks reject the payment.
class EpcQrPayload {
  static const int maxNameLength = 70;
  static const int maxUnstructuredLength = 140;

  static final _ibanRe = RegExp(r'^[A-Z]{2}[0-9]{2}[A-Z0-9]{10,30}$');

  /// Returns a BCD string, or null if the bill cannot be paid by bank QR.
  static String? build({
    required String beneficiaryName,
    required String iban,
    required double amountEur,
    String? paymentMemo,
    String? description,
  }) {
    final name = _clip(_oneLine(beneficiaryName), maxNameLength);
    final cleanIban = normalizeIban(iban);
    if (name.isEmpty || cleanIban == null) return null;
    if (amountEur <= 0 || !amountEur.isFinite || amountEur >= 1000000000) {
      return null;
    }

    final remittance = _unstructured(
      paymentMemo: paymentMemo,
      description: description,
    );

    return [
      'BCD',
      '002',
      '1',
      'SCT',
      '',
      name,
      cleanIban,
      'EUR${amountEur.toStringAsFixed(2)}',
      '',
      '',
      remittance,
    ].join('\n');
  }

  static String? normalizeIban(String? raw) {
    final compact = (raw ?? '').replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (!_ibanRe.hasMatch(compact)) return null;
    return compact;
  }

  static String structuredRemittanceOf(String payload) {
    final lines = payload.split('\n');
    return lines.length > 9 ? lines[9] : '';
  }

  static String unstructuredRemittanceOf(String payload) {
    final lines = payload.split('\n');
    return lines.length > 10 ? lines[10] : '';
  }

  static String _unstructured({
    String? paymentMemo,
    String? description,
  }) {
    final memo = _oneLine(paymentMemo ?? '');
    final note = _oneLine(description ?? '');

    if (memo.isEmpty) {
      return _clip(note, maxUnstructuredLength);
    }
    if (note.isEmpty || note.contains(memo)) {
      return _clip(note.isEmpty ? memo : note, maxUnstructuredLength);
    }

    final combined = '$note $memo';
    if (combined.length <= maxUnstructuredLength) return combined;

    final room = maxUnstructuredLength - memo.length - 1;
    if (room < 1) return _clip(memo, maxUnstructuredLength);
    return '${_clip(note, room)} $memo';
  }

  static String _oneLine(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _clip(String value, int max) {
    if (value.length <= max) return value;
    return value.substring(0, max).trim();
  }
}
