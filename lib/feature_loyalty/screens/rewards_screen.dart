import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_loyalty/models/rewards_ledger_entry_model.dart';
import 'package:slickbill/feature_loyalty/models/rewards_summary_model.dart';
import 'package:slickbill/feature_loyalty/repos/rewards_repo.dart';
import 'package:slickbill/feature_loyalty/utils/loyalty_format.dart';
import 'package:slickbill/shared_widgets/custom_appbar.dart';

class RewardsScreen extends HookWidget {
  const RewardsScreen({super.key});

  String _entryLabel(RewardsLedgerEntryModel entry) {
    switch (entry.entryType.toUpperCase()) {
      case 'EARN':
        return 'lbl_RewardsHistoryEarn'.tr;
      case 'REDEEM':
        return 'lbl_RewardsHistoryRedeem'.tr;
      case 'EXPIRE':
        return 'lbl_RewardsHistoryExpire'.tr;
      default:
        return entry.entryType;
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = useMemoized(() => RewardsRepo());
    final summary = useState<RewardsSummaryModel?>(null);
    final history = useState<List<RewardsLedgerEntryModel>>([]);
    final isLoading = useState(true);
    final error = useState<String?>(null);
    final colors = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('d MMM yyyy');

    Future<void> load() async {
      isLoading.value = true;
      error.value = null;
      try {
        final results = await Future.wait([
          repo.getSummary(),
          repo.listHistory(),
        ]);
        summary.value = results[0] as RewardsSummaryModel;
        history.value = results[1] as List<RewardsLedgerEntryModel>;
      } catch (e) {
        error.value = e is String ? e : e.toString();
      } finally {
        isLoading.value = false;
      }
    }

    useEffect(() {
      load();
      return null;
    }, const []);

    final data = summary.value ?? RewardsSummaryModel.empty;

    return Scaffold(
      backgroundColor: colors.light,
      appBar: CustomAppbar(
        title: 'hd_SlickbillsRewards'.tr,
        appbarIcon: null,
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: isLoading.value
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  if (error.value != null) ...[
                    Text(error.value!, style: TextStyle(color: colors.red)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: load,
                      child: Text('btn_Retry'.tr),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.yellow.withOpacity(0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'lbl_RewardsTotal'.tr,
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: colors.darkGray,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            formatRewardsPoints(data.totalAmount),
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colors.dark,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'lbl_RewardsNotEurHint'.tr,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colors.darkGray,
                                  height: 1.4,
                                ),
                          ),
                          if (!data.redemptionEnabled) ...[
                            const SizedBox(height: 10),
                            Text(
                              'lbl_RewardsRedemptionSoon'.tr,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colors.blue,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'hd_RewardsHistory'.tr,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: colors.dark,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    if (history.value.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'lbl_NoRewardsHistoryYet'.tr,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colors.darkGray,
                              ),
                        ),
                      )
                    else
                      ...history.value.map(
                        (entry) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colors.blue.withOpacity(0.12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '+${formatRewardsPoints(entry.amount)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: colors.dark,
                                          ),
                                    ),
                                    Text(
                                      _entryLabel(entry),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: colors.darkGray),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                dateFormat.format(entry.createdAt.toLocal()),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: colors.darkGray),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}
