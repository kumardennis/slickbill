import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/utils/money_formatter.dart';
import 'package:slickbill/feature_loyalty/models/customer_merchant_relationship_model.dart';
import 'package:slickbill/feature_loyalty/utils/loyalty_badge.dart';

class CustomerMerchantRelationshipRow extends StatelessWidget {
  final CustomerMerchantRelationshipModel relationship;

  const CustomerMerchantRelationshipRow({
    super.key,
    required this.relationship,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final formatter = FormatNumber();
    final badge = relationship.loyaltyBadge;
    final merchantName = relationship.merchantPublicName.isNotEmpty
        ? relationship.merchantPublicName
        : 'lbl_MerchantFallbackName'.tr;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.blue.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colors.blue.withOpacity(0.12),
            child: Icon(Icons.storefront_outlined, color: colors.blue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        merchantName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: colors.dark,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: loyaltyBadgeColor(context, badge).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        loyaltyBadgeLabel(badge),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: loyaltyBadgeColor(context, badge),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
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
                if (relationship.lastActiveMonth.isNotEmpty)
                  Text(
                    'lbl_LastActive'.trParams({
                      'month': relationship.lastActiveMonth,
                    }),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.darkGray,
                          fontSize: 11,
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
