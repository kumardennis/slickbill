import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';

class CustomAppbar extends HookWidget implements PreferredSizeWidget {
  final String title;
  final Widget? appbarIcon;
  final PreferredSizeWidget? tabBar;

  const CustomAppbar(
      {super.key, required this.title, required this.appbarIcon, this.tabBar});

  @override
  Size get preferredSize => Size.fromHeight(140.0);

  @override
  Widget build(BuildContext context) {
    return (AppBar(
      bottom: tabBar,
      backgroundColor: Theme.of(context).colorScheme.dark,
      elevation: 10,
      title: Center(
        child: Text(
          '$title'.tr,
          style: Theme.of(context)
              .textTheme
              .displayMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    ));
  }
}
