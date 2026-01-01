import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/getx_controllers/current_bank_controller.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_auth/screens/sign_in.dart';
import 'package:slickbill/feature_dashboard/screens/add_ibans.dart';
import 'package:slickbill/feature_dashboard/utils/striga_class.dart';
import 'package:slickbill/feature_dashboard/widgets/current_bank_selector.dart';
import 'package:slickbill/feature_dashboard/widgets/user_info.dart';
import 'package:slickbill/feature_dashboard/widgets/wallet_balance.dart';
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
        // Show confirmation dialog
        final confirmed = await Get.dialog<bool>(
          AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.dark,
            title: Text('Sign Out'),
            content: Text('Are you sure you want to sign out?'),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Get.back(result: true),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.red,
                ),
                child: Text('Sign Out'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          // Show loading
          Get.dialog(
            const Center(child: CircularProgressIndicator()),
            barrierDismissible: false,
          );

          // Sign out from Supabase
          await Supabase.instance.client.auth.signOut();

          // Clear user data
          await userController.clearUserData();

          // Close loading dialog
          Get.back();

          // Navigate to sign in
          Get.offAll(() => SignIn());

          // Show success message
          Get.snackbar(
            'Signed Out',
            'You have been successfully signed out',
            backgroundColor: Colors.green.withOpacity(0.1),
            colorText: Colors.green,
            duration: Duration(seconds: 2),
          );
        }
      } catch (e) {
        // Close loading dialog if it's open
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }

        // Show error message
        Get.snackbar(
          'Error',
          'Failed to sign out: ${e.toString()}',
          backgroundColor: Colors.red.withOpacity(0.1),
          colorText: Colors.red,
          duration: Duration(seconds: 3),
        );
      }
    }

    // Bank section
    final hasBankName = userController.user.value.bankAccountName != null;
    return Scaffold(
      appBar: CustomAppbar(title: 'Profile', appbarIcon: null),
      body: SingleChildScrollView(
        child: Container(
          width: MediaQuery.of(context).size.width,
          child: Column(
            children: [
              // UserInfo, WalletBalance, etc...
              UserInfo(),
              const SizedBox(height: 20),
              const WalletBalance(),

              Obx(() {
                final user = userController.user.value;

                // Has IBAN -> show primary bank card (purely from user model)
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
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
                            onPressed: () {
                              Get.to(() => const AddIbanScreen());
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
                                  color: Theme.of(context).colorScheme.blue,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user.bankAccountName ?? '',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      Text(
                        user.iban ?? '',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ],
                  ),
                );
              }),

              // You can keep CurrentBankSelector if you eventually
              // map it to private_users.ibans, otherwise remove it for now.
              // CurrentBankSelector(),

              CurrentBankSelector(),
              // ...rest of widgets...

              // Sign Out Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: handleSignOut,
                    icon: Icon(
                      Icons.logout,
                      color: Colors.white,
                    ),
                    label: Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(vertical: 16),
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
