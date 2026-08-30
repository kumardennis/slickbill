import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_loyalty/models/merchant_check_in_session_model.dart';
import 'package:slickbill/feature_loyalty/screens/merchant_customers_screen.dart';
import 'package:slickbill/feature_loyalty/utils/loyalty_badge.dart';

bool _merchantCheckInAlertOpen = false;

Future<void> showMerchantCheckInAlertSheet({
  required MerchantCheckInSessionModel session,
}) async {
  final context = Get.context;
  if (context == null) return;

  if (_merchantCheckInAlertOpen || Get.isBottomSheetOpen == true) {
    Get.back();
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  _merchantCheckInAlertOpen = true;
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MerchantCheckInAlertSheet(session: session),
    );
  } finally {
    _merchantCheckInAlertOpen = false;
  }
}

class _MerchantCheckInAlertSheet extends StatelessWidget {
  final MerchantCheckInSessionModel session;

  const _MerchantCheckInAlertSheet({required this.session});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

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
          Icon(Icons.person_pin_circle_outlined, size: 48, color: colors.green),
          const SizedBox(height: 12),
          Text(
            'lbl_MerchantCheckInAlertTitle'.tr,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.dark,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'lbl_MerchantCheckInAlertHint'.tr,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.darkGray,
                ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.green.withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.sessionToken.isNotEmpty
                      ? session.sessionToken
                      : 'lbl_ThisUser'.tr,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.dark,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (session.memberCount > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    'lbl_VisitMemberCount'.trParams({
                      'count': '${session.memberCount}',
                    }),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.darkGray,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
                if (session.members.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...session.members.map(
                    (member) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              member.memberToken,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colors.dark,
                                  ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: loyaltyBadgeColor(
                                context,
                                member.loyaltyBadge,
                              ).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              loyaltyBadgeLabel(member.loyaltyBadge),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: loyaltyBadgeColor(
                                      context,
                                      member.loyaltyBadge,
                                    ),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Get.to(() => const MerchantCustomersScreen());
            },
            child: Text('btn_ViewCustomers'.tr),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('btn_Dismiss'.tr),
          ),
        ],
      ),
    );
  }
}
