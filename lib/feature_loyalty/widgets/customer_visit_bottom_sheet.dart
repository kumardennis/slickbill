import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_loyalty/models/customer_active_visit_model.dart';
import 'package:slickbill/feature_loyalty/utils/loyalty_badge.dart';

Future<void> showCustomerVisitBottomSheet({
  required CustomerActiveVisitModel visit,
}) {
  final context = Get.context;
  if (context == null) return Future.value();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => CustomerVisitBottomSheet(visit: visit),
  );
}

class CustomerVisitBottomSheet extends StatelessWidget {
  final CustomerActiveVisitModel visit;

  const CustomerVisitBottomSheet({super.key, required this.visit});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final merchantName = visit.merchantPublicName.isNotEmpty
        ? visit.merchantPublicName
        : 'lbl_MerchantFallbackName'.tr;

    return Container(
      decoration: BoxDecoration(
        color: colors.light,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: colors.lightGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'lbl_VisitAtMerchant'.trParams({'merchant': merchantName}),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.dark,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.green.withOpacity(0.25)),
            ),
            child: Column(
              children: [
                Text(
                  visit.sessionToken,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.dark,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'lbl_YourMemberToken'.trParams({'token': visit.memberToken}),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.darkGray,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    loyaltyBadgeLabel(visit.loyaltyBadge),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.blue,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (visit.memberCount > 1) ...[
                  const SizedBox(height: 8),
                  Text(
                    'lbl_VisitMemberCount'.trParams({
                      'count': '${visit.memberCount}',
                    }),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.darkGray,
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (visit.joinUrl.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'lbl_VisitJoinQrHint'.tr,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.darkGray,
                  ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.lightGray),
                ),
                child: QrImageView(
                  data: visit.joinUrl,
                  size: 160,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('btn_Done'.tr),
            ),
          ),
        ],
      ),
    );
  }
}
