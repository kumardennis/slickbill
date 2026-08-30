import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_loyalty/models/rewards_summary_model.dart';
import 'package:slickbill/feature_loyalty/repos/rewards_repo.dart';
import 'package:slickbill/feature_loyalty/screens/rewards_screen.dart';
import 'package:slickbill/feature_loyalty/utils/loyalty_format.dart';

class RewardsSummaryCard extends HookWidget {
  const RewardsSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = useMemoized(() => RewardsRepo());
    final summary = useState<RewardsSummaryModel?>(null);
    final isLoading = useState(true);
    final error = useState<String?>(null);

    Future<void> load() async {
      isLoading.value = true;
      error.value = null;
      try {
        summary.value = await repo.getSummary();
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

    final colors = Theme.of(context).colorScheme;
    final data = summary.value ?? RewardsSummaryModel.empty;
    final showCard = isLoading.value ||
        error.value != null ||
        data.earnEnabled ||
        data.totalAmount > 0;

    if (!showCard) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.light,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.yellow.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.stars_rounded, color: colors.yellow, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'hd_SlickbillsRewards'.tr,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.dark,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (isLoading.value)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.blue,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'lbl_RewardsNotEurHint'.tr,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.gray,
                  height: 1.35,
                ),
          ),
          if (error.value != null) ...[
            const SizedBox(height: 10),
            Text(
              error.value!,
              style: TextStyle(color: colors.red, fontSize: 12),
            ),
          ] else if (!isLoading.value) ...[
            const SizedBox(height: 14),
            Text(
              'lbl_RewardsTotal'.tr,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.darkGray,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              formatRewardsPoints(data.totalAmount),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: colors.dark,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            if (!data.redemptionEnabled) ...[
              const SizedBox(height: 8),
              Text(
                'lbl_RewardsRedemptionSoon'.tr,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.darkGray,
                    ),
              ),
            ],
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await Get.to(() => const RewardsScreen());
                await load();
              },
              icon: Icon(Icons.card_giftcard_outlined, color: colors.blue),
              label: Text('btn_ViewRewards'.tr),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.blue),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
