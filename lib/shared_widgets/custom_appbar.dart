import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_dashboard/screens/profile.dart';

class CustomAppbar extends HookWidget implements PreferredSizeWidget {
  final String title;
  final Widget? appbarIcon;
  final PreferredSizeWidget? tabBar;
  final bool showSettings;

  const CustomAppbar(
      {super.key,
      required this.title,
      required this.appbarIcon,
      this.tabBar,
      this.showSettings = false});

  @override
  Size get preferredSize => Size.fromHeight(tabBar != null ? 120.0 : 70.0);

  @override
  Widget build(BuildContext context) {
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
                  color:
                      Theme.of(context).colorScheme.darkerBlue.withOpacity(0.1),
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
      actions: appbarIcon != null ? [appbarIcon!] : null,
      bottom: tabBar,
      backgroundColor: Theme.of(context).colorScheme.light,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      title: Text(
        '$title'.tr,
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
  }
}
