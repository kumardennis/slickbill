import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/utils/money_formatter.dart';
import 'package:slickbill/feature_loyalty/models/customer_merchant_relationship_model.dart';
import 'package:slickbill/feature_loyalty/utils/loyalty_badge.dart';

Future<void> showCustomerCheckInBottomSheet({
  required BuildContext context,
  required CustomerMerchantRelationshipModel relationship,
  String sessionToken = '',
  String memberToken = '',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => CustomerCheckInBottomSheet(
      relationship: relationship,
      sessionToken: sessionToken,
      memberToken: memberToken,
    ),
  );
}

class CustomerCheckInBottomSheet extends StatelessWidget {
  final CustomerMerchantRelationshipModel relationship;
  final String sessionToken;
  final String memberToken;

  const CustomerCheckInBottomSheet({
    super.key,
    required this.relationship,
    this.sessionToken = '',
    this.memberToken = '',
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final formatter = FormatNumber();
    final merchantName = relationship.merchantPublicName.isNotEmpty
        ? relationship.merchantPublicName
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
          Icon(Icons.check_circle_outline, size: 48, color: colors.green),
          const SizedBox(height: 12),
          Text(
            'lbl_CheckInAtMerchant'.trParams({'merchant': merchantName}),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.dark,
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (sessionToken.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              sessionToken,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.dark,
                  ),
            ),
            if (memberToken.isNotEmpty)
              Text(
                'lbl_YourMemberToken'.trParams({'token': memberToken}),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.darkGray,
                      fontWeight: FontWeight.w600,
                    ),
              ),
          ],
          const SizedBox(height: 8),
          Text(
            'lbl_CheckInSuccessHint'.tr,
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
              border: Border.all(color: colors.blue.withOpacity(0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'lbl_YourRelationship'.tr,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.darkGray,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    loyaltyBadgeLabel(relationship.loyaltyBadge),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.blue,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(height: 12),
                if (relationship.checkInCount > 0)
                  Text(
                    'lbl_CheckInCount'.trParams({
                      'count': '${relationship.checkInCount}',
                    }),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.dark,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                if (relationship.paidInvoiceCount > 0) ...[
                  Text(
                    'lbl_PaidInvoices'.trParams({
                      'count': '${relationship.paidInvoiceCount}',
                    }),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.dark,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    formatter.formatMoney(relationship.totalPaidEur),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.darkGray,
                        ),
                  ),
                ],
              ],
            ),
          ),
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
