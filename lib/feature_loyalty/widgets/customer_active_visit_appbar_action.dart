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
        child: IconButton(
          tooltip: visit.memberToken.isNotEmpty
              ? visit.memberToken
              : visit.merchantPublicName,
          onPressed: controller.showVisitSheet,
          visualDensity: VisualDensity.compact,
          icon: Icon(
            Icons.storefront_rounded,
            size: 22,
            color: colors.darkerBlue,
          ),
        ),
      );
    });
  }
}
