import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';

String loyaltyBadgeLabel(String badge) {
  switch (badge.toLowerCase()) {
    case 'regular':
      return 'lbl_LoyaltyRegular'.tr;
    case 'returning':
      return 'lbl_LoyaltyReturning'.tr;
    default:
      return 'lbl_LoyaltyNew'.tr;
  }
}

Color loyaltyBadgeColor(BuildContext context, String badge) {
  final colors = Theme.of(context).colorScheme;
  switch (badge.toLowerCase()) {
    case 'regular':
      return colors.green;
    case 'returning':
      return colors.blue;
    default:
      return colors.darkGray;
  }
}
