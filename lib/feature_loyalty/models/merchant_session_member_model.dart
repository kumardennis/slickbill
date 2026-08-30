class MerchantSessionMemberModel {
  final String memberToken;
  final String loyaltyBadge;
  final int paidInvoiceCount;
  final int checkInCount;
  final double totalPaidEur;

  const MerchantSessionMemberModel({
    required this.memberToken,
    required this.loyaltyBadge,
    required this.paidInvoiceCount,
    required this.checkInCount,
    required this.totalPaidEur,
  });

  factory MerchantSessionMemberModel.fromJson(Map<String, dynamic> json) {
    return MerchantSessionMemberModel(
      memberToken: (json['member_token'] ?? json['memberToken'] as String?)
              ?.trim() ??
          '',
      loyaltyBadge:
          (json['loyalty_badge'] ?? json['loyaltyBadge'] as String?)?.trim() ??
              'new',
      paidInvoiceCount:
          (json['paid_invoice_count'] ?? json['paidInvoiceCount'] as num?)
                  ?.toInt() ??
              0,
      checkInCount:
          (json['check_in_count'] ?? json['checkInCount'] as num?)?.toInt() ??
              0,
      totalPaidEur:
          (json['total_paid_eur'] ?? json['totalPaidEur'] as num?)?.toDouble() ??
              0,
    );
  }
}
