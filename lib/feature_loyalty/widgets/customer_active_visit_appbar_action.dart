import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_loyalty/getx_controllers/customer_active_visit_controller.dart';

class CustomerActiveVisitAppBarAction extends StatelessWidget {
  const CustomerActiveVisitAppBarAction({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<CustomerActiveVisitController>()) {
      return const SizedBox.shrink();
    }

    final controller = Get.find<CustomerActiveVisitController>();
    final colors = Theme.of(context).colorScheme;

    return Obx(() {
      final visit = controller.activeVisit.value;
      if (visit == null || visit.sessionToken.isEmpty) {
        return const SizedBox.shrink();
      }

      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: TextButton(
          onPressed: controller.showVisitSheet,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                visit.sessionToken,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.darkerBlue,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Text(
                visit.memberToken,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.darkGray,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
