class CustomerMerchantRelationshipModel {
  final String merchantPublicName;
  final String loyaltyBadge;
  final int checkInCount;
  final int paidInvoiceCount;
  final double totalPaidEur;
  final String lastActiveMonth;

  const CustomerMerchantRelationshipModel({
    required this.merchantPublicName,
    required this.loyaltyBadge,
    required this.checkInCount,
    required this.paidInvoiceCount,
    required this.totalPaidEur,
    required this.lastActiveMonth,
  });

  factory CustomerMerchantRelationshipModel.fromJson(Map<String, dynamic> json) {
    return CustomerMerchantRelationshipModel(
      merchantPublicName:
          (json['merchantPublicName'] ?? json['merchant_public_name'] as String?)
                  ?.trim() ??
              '',
      loyaltyBadge:
          (json['loyaltyBadge'] ?? json['loyalty_badge'] as String?)?.trim() ??
              'new',
      checkInCount:
          (json['checkInCount'] ?? json['check_in_count'] as num?)?.toInt() ?? 0,
      paidInvoiceCount:
          (json['paidInvoiceCount'] ?? json['paid_invoice_count'] as num?)
                  ?.toInt() ??
              0,
      totalPaidEur:
          (json['totalPaidEur'] ?? json['total_paid_eur'] as num?)?.toDouble() ??
              0,
      lastActiveMonth:
          (json['lastActiveMonth'] ?? json['last_active_month'] as String?)
                  ?.trim() ??
              '',
    );
  }
}
