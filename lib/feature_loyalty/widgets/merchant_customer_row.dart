import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/utils/money_formatter.dart';
import 'package:slickbill/feature_loyalty/models/merchant_customer_link_model.dart';
import 'package:slickbill/feature_loyalty/utils/loyalty_badge.dart';

class MerchantCustomerRow extends StatelessWidget {
  final MerchantCustomerLinkModel customer;

  const MerchantCustomerRow({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final formatter = FormatNumber();
    final badge = customer.loyaltyBadge;

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
            child: Icon(Icons.person_outline, color: colors.blue, size: 20),
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
                        'lbl_ThisUser'.tr,
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
                Text(
                  'lbl_PaidInvoices'.trParams({
                    'count': '${customer.paidInvoiceCount}',
                  }),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.dark,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  formatter.formatMoney(customer.totalPaidEur),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.darkGray,
                      ),
                ),
                if (customer.lastActiveMonth.isNotEmpty)
                  Text(
                    'lbl_LastActive'.trParams({
                      'month': customer.lastActiveMonth,
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
