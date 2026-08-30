class MerchantSessionBillResultModel {
  final int invoiceId;
  final double amount;
  final int sessionId;
  final String sessionToken;
  final String memberToken;
  final String description;

  const MerchantSessionBillResultModel({
    required this.invoiceId,
    required this.amount,
    required this.sessionId,
    required this.sessionToken,
    required this.memberToken,
    required this.description,
  });

  factory MerchantSessionBillResultModel.fromJson(Map<String, dynamic> json) {
    return MerchantSessionBillResultModel(
      invoiceId: (json['invoiceId'] ?? json['invoice_id'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      sessionId: (json['sessionId'] ?? json['session_id'] as num?)?.toInt() ?? 0,
      sessionToken:
          (json['sessionToken'] ?? json['session_token'] as String?)?.trim() ??
              '',
      memberToken:
          (json['memberToken'] ?? json['member_token'] as String?)?.trim() ??
              '',
      description: (json['description'] as String?)?.trim() ?? '',
    );
  }
}
