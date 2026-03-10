import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/core/services/push_notification_service.dart';
import 'package:slickbill/feature_auth/getx_controllers/current_bank_controller.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_auth/screens/sign_in.dart';
import 'package:slickbill/feature_dashboard/screens/add_ibans.dart';
import 'package:slickbill/feature_dashboard/widgets/cdp_wallet_balance.dart';
import 'package:slickbill/feature_dashboard/widgets/current_bank_selector.dart';
import 'package:slickbill/feature_dashboard/widgets/user_info.dart';
import 'package:slickbill/feature_dashboard/widgets/wallet_balance.dart';
import 'package:slickbill/services/coinbase/coinbase_service.dart';
import 'package:slickbill/shared_widgets/custom_appbar.dart';
import 'package:slickbill/shared_widgets/input_field.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Profile extends HookWidget {
  const Profile({super.key});

  @override
  Widget build(BuildContext context) {
    UserController userController = Get.put(UserController());
    CurrentBankController currentBankController =
        Get.put(CurrentBankController());

    Future<void> handleSignOut() async {
      try {
        final confirmed = await Get.dialog<bool>(
          AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.dark,
            title: const Text('Sign Out'),
            content: const Text('Are you sure you want to sign out?'),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Get.back(result: true),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.red,
                ),
                child: const Text('Sign Out'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          Get.dialog(
            const Center(child: CircularProgressIndicator()),
            barrierDismissible: false,
          );
          await PushNotificationService.logoutUser();
          await Supabase.instance.client.auth.signOut();

          await userController.clearUserData();

          Get.back();

          Get.offAll(() => const SignIn());

          Get.snackbar(
            'Signed Out',
            'You have been successfully signed out',
            backgroundColor: Colors.green.withOpacity(0.1),
            colorText: Colors.green,
            duration: const Duration(seconds: 2),
          );
        }
      } catch (e) {
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }

        Get.snackbar(
          'Error',
          'Failed to sign out: ${e.toString()}',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    }

    // Bank section
    return Scaffold(
      appBar: const CustomAppbar(title: 'Profile', appbarIcon: null),
      body: SingleChildScrollView(
        child: Container(
          width: MediaQuery.of(context).size.width,
          child: Column(
            children: [
              UserInfo(),
              const SizedBox(height: 20),

              Obx(() {
                final hasWallet = true;

                print(
                    'User has wallet: ${userController.user.value.cdpWalletId}');

                return Stack(
                  children: [
                    // const WalletBalance(),
                    const CdpWalletBalance(),
                    if (!hasWallet)
                      Positioned(
                        top: 0,
                        right: 0,
                        left: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.wallet_outlined,
                                color: Colors.white,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Crypto Wallet',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.orange,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'COMING SOON',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  'Send and receive crypto payments directly',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              }),

              const SizedBox(height: 20),

              // Bank Account Section
              Obx(() {
                final user = userController.user.value;
                return Container(
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
                              // ✅ Navigate and wait for result
                              final result =
                                  await Get.to(() => const AddIbanScreen());

                              // ✅ Refresh the entire page if bank was added
                              if (result == true) {
                                // Reload both controllers
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
                      if (user.bankAccountName != null)
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
                                        color:
                                            Theme.of(context).colorScheme.blue,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              user.bankAccountName ?? '',
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
                );
              }),

              const SizedBox(height: 20),
              const CurrentBankSelector(),
              const SizedBox(height: 20),

              // Sign Out Button
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
              const SizedBox(height: 40), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }
}
