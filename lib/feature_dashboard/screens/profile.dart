import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
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

    // Bank section
    return Scaffold(
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
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.light,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20.0,
                            vertical: 12.0,
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final result =
                                    await Get.to(() => const AddIbanScreen());
                                if (result == true) {
                                  await userController.loadUserData();
                                }
                              },
                              icon: Icon(
                                Icons.add,
                                color: Theme.of(context).colorScheme.blue,
                              ),
                              label: Text(
                                'Add bank account / IBAN',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: Theme.of(context).colorScheme.blue,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Theme.of(context).colorScheme.blue,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if ((user.bankName?.trim().isNotEmpty ?? false) ||
                            (user.bankAccountName?.trim().isNotEmpty ?? false))
                          Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.account_balance,
                                    color: Theme.of(context).colorScheme.blue,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Primary Bank Account',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .blue,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                (user.bankName?.trim().isNotEmpty ?? false)
                                    ? user.bankName!
                                    : (user.bankAccountName ?? ''),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: Theme.of(context).colorScheme.blue,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              Text(
                                user.iban ?? '',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: Theme.of(context).colorScheme.blue,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
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
                          backgroundColor: Colors.red,
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
    );
  }
}
