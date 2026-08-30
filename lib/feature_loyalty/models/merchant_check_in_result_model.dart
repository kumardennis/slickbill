import 'customer_merchant_relationship_model.dart';

class MerchantCheckInResultModel {
  final int sessionId;
  final String sessionToken;
  final String memberToken;
  final String joinCode;
  final String joinUrl;
  final String status;
  final int memberCount;
  final String loyaltyBadge;
  final String merchantPublicName;
  final int checkInCount;
  final int paidInvoiceCount;
  final double totalPaidEur;
  final String lastActiveMonth;

  const MerchantCheckInResultModel({
    required this.sessionId,
    required this.sessionToken,
    required this.memberToken,
    required this.joinCode,
    required this.joinUrl,
    required this.status,
    required this.memberCount,
    required this.loyaltyBadge,
    required this.merchantPublicName,
    required this.checkInCount,
    required this.paidInvoiceCount,
    required this.totalPaidEur,
    required this.lastActiveMonth,
  });

  factory MerchantCheckInResultModel.fromJson(Map<String, dynamic> json) {
    return MerchantCheckInResultModel(
      sessionId: (json['sessionId'] ?? json['session_id'] as num?)?.toInt() ?? 0,
      sessionToken:
          (json['sessionToken'] ?? json['session_token'] as String?)?.trim() ??
              '',
      memberToken:
          (json['memberToken'] ?? json['member_token'] as String?)?.trim() ?? '',
      joinCode:
          (json['joinCode'] ?? json['join_code'] as String?)?.trim() ?? '',
      joinUrl: (json['joinUrl'] ?? json['join_url'] as String?)?.trim() ?? '',
      status: (json['status'] as String?)?.trim() ?? 'OPEN',
      memberCount:
          (json['memberCount'] ?? json['member_count'] as num?)?.toInt() ?? 1,
      loyaltyBadge: (json['loyaltyBadge'] ?? json['loyalty_badge'] as String?)
              ?.trim() ??
          'new',
      merchantPublicName:
          (json['merchantPublicName'] ?? json['merchant_public_name'] as String?)
                  ?.trim() ??
              '',
      checkInCount:
          (json['checkInCount'] ?? json['check_in_count'] as num?)?.toInt() ??
              0,
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

  CustomerMerchantRelationshipModel get relationship =>
      CustomerMerchantRelationshipModel(
        merchantPublicName: merchantPublicName,
        loyaltyBadge: loyaltyBadge,
        checkInCount: checkInCount,
        paidInvoiceCount: paidInvoiceCount,
        totalPaidEur: totalPaidEur,
        lastActiveMonth: lastActiveMonth,
      );
}
