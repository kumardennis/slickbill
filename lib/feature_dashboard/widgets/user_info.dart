import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:slickbill/feature_auth/getx_controllers/current_bank_controller.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/theme/sb_colors.dart';

class UserInfo extends HookWidget {
  UserInfo({super.key});
  UserController userController = Get.find();
  CurrentBankController currentBankController =
      Get.put(CurrentBankController());

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final user = userController.user.value;
      final personalName = [
        user.firstName,
        user.lastName,
      ]
          .whereType<String>()
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .join(' ');
      final displayName = personalName.isNotEmpty
          ? personalName
          : (user.fullName?.trim().isNotEmpty == true
              ? user.fullName!
              : 'No user');
      final avatarLetter =
          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
      final username = user.username.trim();

      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SbColors.surfaceLowest,
          borderRadius: BorderRadius.circular(SbRadii.md),
          boxShadow: SbShadows.cardSoft,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: SbColors.deepNavy,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  avatarLetter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: SbColors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (username.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '@$username',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: SbColors.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: user.isBusiness
                    ? SbColors.warningAmber.withValues(alpha: 0.12)
                    : SbColors.deepNavy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(SbRadii.full),
              ),
              child: Text(
                user.isBusiness ? 'lbl_Business'.tr : 'lbl_Private'.tr,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: user.isBusiness
                          ? SbColors.warningAmber
                          : SbColors.deepNavy,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
