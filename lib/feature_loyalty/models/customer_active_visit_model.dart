class CustomerActiveVisitModel {
  final int sessionId;
  final String sessionToken;
  final String memberToken;
  final String joinCode;
  final String joinUrl;
  final String merchantPublicName;
  final String loyaltyBadge;
  final int memberCount;

  const CustomerActiveVisitModel({
    required this.sessionId,
    required this.sessionToken,
    required this.memberToken,
    required this.joinCode,
    required this.joinUrl,
    required this.merchantPublicName,
    required this.loyaltyBadge,
    required this.memberCount,
  });

  factory CustomerActiveVisitModel.fromJson(Map<String, dynamic> json) {
    return CustomerActiveVisitModel(
      sessionId: (json['sessionId'] ?? json['session_id'] as num?)?.toInt() ?? 0,
      sessionToken:
          (json['sessionToken'] ?? json['session_token'] as String?)?.trim() ??
              '',
      memberToken:
          (json['memberToken'] ?? json['member_token'] as String?)?.trim() ??
              '',
      joinCode:
          (json['joinCode'] ?? json['join_code'] as String?)?.trim() ?? '',
      joinUrl: (json['joinUrl'] ?? json['join_url'] as String?)?.trim() ?? '',
      merchantPublicName:
          (json['merchantPublicName'] ?? json['merchant_public_name'] as String?)
                  ?.trim() ??
              '',
      loyaltyBadge:
          (json['loyaltyBadge'] ?? json['loyalty_badge'] as String?)?.trim() ??
              'new',
      memberCount:
          (json['memberCount'] ?? json['member_count'] as num?)?.toInt() ?? 1,
    );
  }
}
