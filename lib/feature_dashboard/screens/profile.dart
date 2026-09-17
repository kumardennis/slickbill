import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:slickbill/feature_auth/getx_controllers/current_bank_controller.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_dashboard/screens/add_ibans.dart';
import 'package:slickbill/feature_dashboard/widgets/current_bank_selector.dart';
import 'package:slickbill/feature_dashboard/widgets/monerium_balance_card.dart';
import 'package:slickbill/feature_dashboard/widgets/monerium_kyc_status_card.dart';
import 'package:slickbill/feature_dashboard/widgets/user_info.dart';
import 'package:slickbill/feature_dashboard/widgets/wallet_info.dart';
import 'package:slickbill/feature_dashboard/widgets/business_profile_card.dart';
import 'package:slickbill/feature_loyalty/widgets/customer_my_merchants_entry.dart';
import 'package:slickbill/feature_loyalty/widgets/rewards_summary_card.dart';
import 'package:slickbill/shared_widgets/custom_appbar.dart';
import 'package:slickbill/shared_widgets/sb_page_background.dart';
import 'package:slickbill/theme/sb_colors.dart';

class Profile extends HookWidget {
  const Profile({super.key});

  @override
  Widget build(BuildContext context) {
    UserController userController = Get.isRegistered<UserController>()
        ? Get.find<UserController>()
        : Get.put(UserController());
    Get.put(CurrentBankController());

    useEffect(() {
      userController.ensureSignedInOrRedirect();
      return null;
    }, const []);

    Future<void> handleSignOut() async {
      final confirmed = await Get.dialog<bool>(
        AlertDialog(
          backgroundColor: SbColors.surfaceLowest,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SbRadii.lg),
            side: const BorderSide(color: SbColors.outlineVariant),
          ),
          title: Text(
            'Sign Out',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: SbColors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
          ),
          content: Text(
            'Are you sure you want to sign out?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: SbColors.onSurfaceVariant,
                ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              style: TextButton.styleFrom(
                foregroundColor: SbColors.onSurfaceVariant,
              ),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Get.back(result: true),
              style: TextButton.styleFrom(
                foregroundColor: SbColors.error,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );
      await userController.forceLogout();
    }

    return SbPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const CustomAppbar(title: 'Profile', appbarIcon: null),
        body: Obx(
        () {
          final user = userController.user.value;
          final moneriumUserId =
              (user.privateUserId != null && user.privateUserId! > 0)
                  ? user.privateUserId.toString()
                  : user.id.toString();

          return SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              child: Column(
                children: [
                  MoneriumBalanceCard(user: user),
                  if (!user.isBusiness) const RewardsSummaryCard(),
                  UserInfo(),
                  const CustomerMyMerchantsEntry(),
                  const BusinessProfileCard(),
                  const WalletInfo(),
                  MoneriumKycStatusCard(userId: moneriumUserId),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: SbColors.surfaceLowest,
                      borderRadius: BorderRadius.circular(SbRadii.md),
                      boxShadow: SbShadows.cardSoft,
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final result =
                                  await Get.to(() => const AddIbanScreen());
                              if (result == true) {
                                await userController.loadUserData();
                              }
                            },
                            icon: const Icon(
                              Icons.add,
                              color: SbColors.deepNavy,
                            ),
                            label: Text(
                              'Add bank account / IBAN',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: SbColors.deepNavy,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: SbColors.deepNavy),
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(SbRadii.md),
                              ),
                            ),
                          ),
                        ),
                        if ((user.bankName?.trim().isNotEmpty ?? false) ||
                            (user.bankAccountName?.trim().isNotEmpty ?? false) ||
                            (user.iban?.trim().isNotEmpty ?? false)) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Your IBANs',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: SbColors.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              user.iban ?? '',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: SbColors.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          if ((user.bankAccountName?.trim().isNotEmpty ??
                                  false) ||
                              (user.bankName?.trim().isNotEmpty ?? false))
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                [
                                  if (user.bankAccountName
                                          ?.trim()
                                          .isNotEmpty ??
                                      false)
                                    user.bankAccountName!.trim(),
                                  if (user.bankName?.trim().isNotEmpty ??
                                      false)
                                    user.bankName!.trim(),
                                ].join(' · '),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: SbColors.onSurfaceVariant,
                                    ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const CurrentBankSelector(),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: handleSignOut,
                        icon: const Icon(
                          Icons.logout,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Sign Out',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SbColors.error,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
      ),
    );
  }
}
