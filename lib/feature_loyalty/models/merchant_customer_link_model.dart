class MerchantCustomerLinkModel {
  final String loyaltyBadge;
  final int paidInvoiceCount;
  final int checkInCount;
  final double totalPaidEur;
  final String lastActiveMonth;

  const MerchantCustomerLinkModel({
    required this.loyaltyBadge,
    required this.paidInvoiceCount,
    this.checkInCount = 0,
    required this.totalPaidEur,
    required this.lastActiveMonth,
  });

  factory MerchantCustomerLinkModel.fromJson(Map<String, dynamic> json) {
    return MerchantCustomerLinkModel(
      loyaltyBadge: (json['loyalty_badge'] as String?)?.trim() ?? 'new',
      paidInvoiceCount: (json['paid_invoice_count'] as num?)?.toInt() ?? 0,
      checkInCount: (json['check_in_count'] as num?)?.toInt() ?? 0,
      totalPaidEur: (json['total_paid_eur'] as num?)?.toDouble() ?? 0,
      lastActiveMonth: (json['last_active_month'] as String?)?.trim() ?? '',
    );
  }
}
