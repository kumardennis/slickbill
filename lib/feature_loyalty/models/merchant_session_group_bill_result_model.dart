class MerchantSessionGroupBillLineModel {
  final int invoiceId;
  final String memberToken;
  final double amount;

  const MerchantSessionGroupBillLineModel({
    required this.invoiceId,
    required this.memberToken,
    required this.amount,
  });

  factory MerchantSessionGroupBillLineModel.fromJson(Map<String, dynamic> json) {
    return MerchantSessionGroupBillLineModel(
      invoiceId: (json['invoiceId'] ?? json['invoice_id'] as num?)?.toInt() ?? 0,
      memberToken:
          (json['memberToken'] ?? json['member_token'] as String?)?.trim() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class MerchantSessionGroupBillResultModel {
  final int privateGroupId;
  final int sessionId;
  final String sessionToken;
  final String description;
  final List<MerchantSessionGroupBillLineModel> invoices;

  const MerchantSessionGroupBillResultModel({
    required this.privateGroupId,
    required this.sessionId,
    required this.sessionToken,
    required this.description,
    required this.invoices,
  });

  factory MerchantSessionGroupBillResultModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawInvoices = json['invoices'];
    final lines = rawInvoices is List
        ? rawInvoices
            .whereType<Map>()
            .map((row) => MerchantSessionGroupBillLineModel.fromJson(
                  Map<String, dynamic>.from(row),
                ))
            .toList()
        : <MerchantSessionGroupBillLineModel>[];

    return MerchantSessionGroupBillResultModel(
      privateGroupId:
          (json['privateGroupId'] ?? json['private_group_id'] as num?)?.toInt() ??
              0,
      sessionId: (json['sessionId'] ?? json['session_id'] as num?)?.toInt() ?? 0,
      sessionToken:
          (json['sessionToken'] ?? json['session_token'] as String?)?.trim() ??
              '',
      description: (json['description'] as String?)?.trim() ?? '',
      invoices: lines,
    );
  }
}
