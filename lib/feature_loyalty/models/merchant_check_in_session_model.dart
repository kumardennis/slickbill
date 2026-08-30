import 'merchant_session_member_model.dart';

class MerchantCheckInSessionModel {
  final int sessionId;
  final String sessionToken;
  final DateTime? openedAt;
  final int memberCount;
  final List<MerchantSessionMemberModel> members;

  const MerchantCheckInSessionModel({
    required this.sessionId,
    required this.sessionToken,
    required this.openedAt,
    required this.memberCount,
    this.members = const [],
  });

  /// First member badge — used for compact alert sheet fallback.
  String get loyaltyBadge =>
      members.isNotEmpty ? members.first.loyaltyBadge : 'new';

  int get checkInCount =>
      members.isNotEmpty ? members.first.checkInCount : 0;

  int get paidInvoiceCount =>
      members.isNotEmpty ? members.first.paidInvoiceCount : 0;

  double get totalPaidEur =>
      members.isNotEmpty ? members.first.totalPaidEur : 0;

  factory MerchantCheckInSessionModel.fromJson(Map<String, dynamic> json) {
    final membersRaw = json['members'];
    final members = membersRaw is List
        ? membersRaw
            .whereType<Map>()
            .map((row) => MerchantSessionMemberModel.fromJson(
                  Map<String, dynamic>.from(row),
                ))
            .toList()
        : <MerchantSessionMemberModel>[];

    return MerchantCheckInSessionModel(
      sessionId: (json['session_id'] ?? json['sessionId'] as num?)?.toInt() ?? 0,
      sessionToken:
          (json['session_token'] ?? json['sessionToken'] as String?)?.trim() ??
              '',
      openedAt: json['opened_at'] != null || json['openedAt'] != null
          ? DateTime.tryParse(
              (json['opened_at'] ?? json['openedAt']).toString(),
            )
          : null,
      memberCount:
          (json['member_count'] ?? json['memberCount'] as num?)?.toInt() ??
              members.length,
      members: members,
    );
  }
}
