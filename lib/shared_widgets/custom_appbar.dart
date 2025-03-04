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
  Size get preferredSize => const Size.fromHeight(120.0);

  @override
  Widget build(BuildContext context) {
    return (AppBar(
      automaticallyImplyLeading: true,
      leading: showSettings
          ? GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Profile()),
                );
              },
              child: Center(child: FaIcon(FontAwesomeIcons.gear)))
          : null,
      bottom: tabBar,
      backgroundColor: Theme.of(context).colorScheme.light,
      elevation: 10,
      title: Center(
        child: Text(
          '$title'.tr,
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.darkGray),
        ),
      ),
    ));
  }
}
