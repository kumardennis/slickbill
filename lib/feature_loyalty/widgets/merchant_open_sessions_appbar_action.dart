import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_loyalty/getx_controllers/merchant_open_sessions_controller.dart';

class MerchantOpenSessionsAppBarAction extends StatelessWidget {
  const MerchantOpenSessionsAppBarAction({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<MerchantOpenSessionsController>()) {
      return const SizedBox.shrink();
    }

    final controller = Get.find<MerchantOpenSessionsController>();
    final colors = Theme.of(context).colorScheme;

    return Obx(() {
      final count = controller.openSessionCount.value;
      if (count <= 0) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: IconButton(
          tooltip: 'btn_OpenCashier'.trParams({'count': '$count'}),
          onPressed: controller.openCashier,
          icon: Badge(
            label: Text(
              count > 9 ? '9+' : '$count',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
            backgroundColor: colors.green,
            child: FaIcon(
              FontAwesomeIcons.userCheck,
              size: 18,
              color: colors.darkerBlue,
            ),
          ),
        ),
      );
    });
  }
}
