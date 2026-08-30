class RewardsLedgerEntryModel {
  final int id;
  final String entryType;
  final double amount;
  final String status;
  final int? invoiceId;
  final DateTime? expiresAt;
  final DateTime createdAt;

  const RewardsLedgerEntryModel({
    required this.id,
    required this.entryType,
    required this.amount,
    required this.status,
    this.invoiceId,
    this.expiresAt,
    required this.createdAt,
  });

  factory RewardsLedgerEntryModel.fromJson(Map<String, dynamic> json) {
    return RewardsLedgerEntryModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      entryType: (json['entry_type'] ?? json['entryType'] as String?)?.trim() ??
          'EARN',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: (json['status'] as String?)?.trim() ?? 'PENDING',
      invoiceId: (json['invoice_id'] ?? json['invoiceId'] as num?)?.toInt(),
      expiresAt: _parseDate(json['expires_at'] ?? json['expiresAt']),
      createdAt: _parseDate(json['created_at'] ?? json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text)?.toUtc();
  }
}
