import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_dashboard/screens/profile.dart';
import 'package:slickbill/feature_loyalty/getx_controllers/customer_active_visit_controller.dart';
import 'package:slickbill/feature_loyalty/widgets/customer_active_visit_appbar_action.dart';
import 'package:slickbill/feature_loyalty/widgets/merchant_open_sessions_appbar_action.dart';
import 'package:slickbill/theme/sb_colors.dart';

class CustomAppbar extends HookWidget implements PreferredSizeWidget {
  final String title;
  final Widget? appbarIcon;
  final PreferredSizeWidget? tabBar;
  final bool showSettings;
  final bool hideMerchantSessionAction;
  final bool showBrand;

  const CustomAppbar(
      {super.key,
      required this.title,
      required this.appbarIcon,
      this.tabBar,
      this.showSettings = false,
      this.hideMerchantSessionAction = false,
      this.showBrand = false});

  @override
  Size get preferredSize =>
      Size.fromHeight(64.0 + (tabBar?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isBusiness = Get.isRegistered<UserController>() &&
          Get.find<UserController>().user.value.isBusiness;

      String checkInName = '';
      if (Get.isRegistered<CustomerActiveVisitController>()) {
        final visit =
            Get.find<CustomerActiveVisitController>().activeVisit.value;
        if (visit != null && visit.sessionToken.isNotEmpty) {
          checkInName = visit.memberToken.trim().isNotEmpty
              ? visit.memberToken.trim()
              : visit.merchantPublicName.trim();
        }
      }

      final accountLabel =
          isBusiness ? 'lbl_BusinessAccount'.tr : 'lbl_PrivateAccount'.tr;

      return AppBar(
        automaticallyImplyLeading: !showBrand && !showSettings,
        leading: showBrand
            ? null
            : (showSettings
                ? IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const Profile()),
                      );
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: SbColors.deepNavy.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const FaIcon(
                        FontAwesomeIcons.gear,
                        color: SbColors.deepNavy,
                        size: 18,
                      ),
                    ),
                  )
                : null),
        actions: [
          if (isBusiness && !hideMerchantSessionAction)
            const MerchantOpenSessionsAppBarAction()
          else if (!isBusiness)
            const CustomerActiveVisitAppBarAction(),
          if (appbarIcon != null) appbarIcon!,
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isBusiness
                        ? SbColors.warningAmber.withValues(alpha: 0.12)
                        : SbColors.deepNavy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(SbRadii.full),
                  ),
                  child: Text(
                    accountLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: isBusiness
                              ? SbColors.warningAmber
                              : SbColors.deepNavy,
                          fontSize: 11,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: showSettings
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const Profile()),
                          );
                        }
                      : null,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: SbColors.deepNavy,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: tabBar,
        backgroundColor: SbColors.surface.withValues(alpha: 0.88),
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: showBrand
            ? Row(
                children: [
                  Image.asset(
                    'assets/logo_icon_big.png',
                    height: 28,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.receipt_long_rounded,
                      color: SbColors.secondaryContainer,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'SlickBills',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: SbColors.onSurface,
                                letterSpacing: -0.2,
                              ),
                        ),
                        if (checkInName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            checkInName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: SbColors.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              )
            : Text(
                title.tr,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.darkerBlue,
                    ),
              ),
        centerTitle: false,
      );
    });
  }
}
