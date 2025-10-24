import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/getx_controllers/current_bank_controller.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_dashboard/utils/striga_class.dart';
import 'package:slickbill/feature_dashboard/widgets/current_bank_selector.dart';
import 'package:slickbill/feature_dashboard/widgets/user_info.dart';
import 'package:slickbill/feature_dashboard/widgets/wallet_balance.dart';
import 'package:slickbill/shared_widgets/custom_appbar.dart';
import 'package:slickbill/shared_widgets/input_field.dart';

class Profile extends HookWidget {
  const Profile({super.key});

  @override
  Widget build(BuildContext context) {
    UserController userController = Get.find();
    CurrentBankController currentBankController =
        Get.put(CurrentBankController());

    return (Scaffold(
      appBar: CustomAppbar(title: 'Profile', appbarIcon: null),
      body: SingleChildScrollView(
        child: Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: Column(children: [
            // User Info Card
            UserInfo(),
            const SizedBox(height: 20),
            const WalletBalance(),

            if (userController.user.value.bankAccountName != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.light,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Obx(
                  () => Column(
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
                                  color: Theme.of(context).colorScheme.blue,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        userController.user.value.bankAccountName!,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      Text(
                        currentBankController.current.value.iban!,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      Text(
                        currentBankController.current.value.bankName,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            CurrentBankSelector()
          ]),
        ),
      ),
    ));
  }
}
