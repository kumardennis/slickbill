import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/utils/money_formatter.dart';
import 'package:slickbill/feature_loyalty/models/merchant_dashboard_model.dart';

class MerchantInsightsKpiRow extends StatelessWidget {
  final MerchantDashboardModel dashboard;

  const MerchantInsightsKpiRow({super.key, required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final navy = Theme.of(context).colorScheme.blue;
    final formatter = FormatNumber();

    Widget kpi(String label, String value, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: navy.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: navy.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: navy),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: navy,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.darkGray,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            kpi(
              'lbl_UniqueCustomers'.tr,
              '${dashboard.uniqueCustomers}',
              Icons.people_outline,
            ),
            const SizedBox(width: 10),
            kpi(
              'lbl_RepeatCustomers'.tr,
              '${dashboard.repeatCustomers}',
              Icons.repeat,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            kpi(
              'lbl_RegularCustomers'.tr,
              '${dashboard.regularCustomers}',
              Icons.star_outline,
            ),
            const SizedBox(width: 10),
            kpi(
              'lbl_TotalViaSlickbills'.tr,
              formatter.formatMoney(dashboard.totalReceivedEur),
              Icons.euro,
            ),
          ],
        ),
      ],
    );
  }
}
