import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_dashboard/screens/profile.dart';
import 'package:slickbill/feature_dashboard/widgets/from_business_badge.dart';
import 'package:slickbill/feature_loyalty/widgets/customer_active_visit_appbar_action.dart';
import 'package:slickbill/feature_loyalty/widgets/merchant_open_sessions_appbar_action.dart';

class CustomAppbar extends HookWidget implements PreferredSizeWidget {
  final String title;
  final Widget? appbarIcon;
  final PreferredSizeWidget? tabBar;
  final bool showSettings;
  final bool hideMerchantSessionAction;

  const CustomAppbar(
      {super.key,
      required this.title,
      required this.appbarIcon,
      this.tabBar,
      this.showSettings = false,
      this.hideMerchantSessionAction = false});

  @override
  Size get preferredSize =>
      Size.fromHeight(70.0 + (tabBar?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isBusiness = Get.isRegistered<UserController>() &&
          Get.find<UserController>().user.value.isBusiness;

      return AppBar(
        automaticallyImplyLeading: true,
        leading: showSettings
            ? IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const Profile()),
                  );
                },
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .darkerBlue
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.gear,
                    color: Theme.of(context).colorScheme.darkerBlue,
                    size: 18,
                  ),
                ),
              )
            : null,
        actions: [
          if (isBusiness && !hideMerchantSessionAction)
            const MerchantOpenSessionsAppBarAction()
          else if (!isBusiness)
            const CustomerActiveVisitAppBarAction(),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: FromBusinessBadge(isBusiness: isBusiness),
            ),
          ),
          if (appbarIcon != null) appbarIcon!,
        ],
        bottom: tabBar,
        backgroundColor: Theme.of(context).colorScheme.light,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(
          title.tr,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.darkerBlue,
                letterSpacing: 0.5,
              ),
        ),
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(0),
          ),
        ),
      );
    });
  }
}
