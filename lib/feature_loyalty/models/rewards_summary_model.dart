import 'rewards_ledger_entry_model.dart';

class RewardsSummaryModel {
  final double pendingAmount;
  final double lockedAmount;
  final bool earnEnabled;
  final bool redemptionEnabled;
  final List<RewardsLedgerEntryModel> recentEntries;

  const RewardsSummaryModel({
    required this.pendingAmount,
    required this.lockedAmount,
    required this.earnEnabled,
    required this.redemptionEnabled,
    this.recentEntries = const [],
  });

  static const empty = RewardsSummaryModel(
    pendingAmount: 0,
    lockedAmount: 0,
    earnEnabled: true,
    redemptionEnabled: false,
  );

  /// All earned promo points (pending + saved). Pending should stay 0 after auto-earn migration.
  double get totalAmount => pendingAmount + lockedAmount;

  factory RewardsSummaryModel.fromJson(Map<String, dynamic> json) {
    final entriesRaw = json['recentEntries'] ?? json['recent_entries'];
    final entries = entriesRaw is List
        ? entriesRaw
            .whereType<Map>()
            .map((row) => RewardsLedgerEntryModel.fromJson(
                  Map<String, dynamic>.from(row),
                ))
            .toList()
        : <RewardsLedgerEntryModel>[];

    final totalFromApi =
        (json['totalAmount'] ?? json['total_amount'] as num?)?.toDouble();

    var pending =
        (json['pendingAmount'] ?? json['pending_amount'] as num?)?.toDouble() ??
            0;
    var locked =
        (json['lockedAmount'] ?? json['locked_amount'] as num?)?.toDouble() ??
            0;

    if (totalFromApi != null && pending + locked == 0 && totalFromApi > 0) {
      locked = totalFromApi;
    }

    return RewardsSummaryModel(
      pendingAmount: pending,
      lockedAmount: locked,
      earnEnabled:
          (json['earnEnabled'] ?? json['earn_enabled'] as bool?) ?? true,
      redemptionEnabled: (json['redemptionEnabled'] ??
              json['redemption_enabled'] as bool?) ??
          false,
      recentEntries: entries,
    );
  }
}
