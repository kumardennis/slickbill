import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/getx_controllers/current_bank_controller.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_auth/models/user_model.dart';

class CurrentBankSelector extends HookWidget {
  @override
  Widget build(BuildContext context) {
    UserController userController = Get.find();
    CurrentBankController currentBankController = Get.find();

    var selectedIban =
        useState<String?>(currentBankController.current.value.iban);

    return Center(
      child: Column(
        children: [
          // Bank IBANs Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bank Accounts',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.darkerBlue,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                if (userController.user.value.ibans?.isNotEmpty == true)
                  ...userController.user.value.ibans!
                      .map(
                        (bankAccount) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () {
                              selectedIban.value = bankAccount.iban;
                              // Update the current bank controller
                              currentBankController.loadCurrentBank(BankAccount(
                                bankName: bankAccount.bankName,
                                iban: bankAccount.iban,
                              ));
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: selectedIban.value == bankAccount.iban
                                      ? Theme.of(context).colorScheme.darkerBlue
                                      : Colors.grey.shade300,
                                  width: selectedIban.value == bankAccount.iban
                                      ? 2
                                      : 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                color: selectedIban.value == bankAccount.iban
                                    ? Theme.of(context)
                                        .colorScheme
                                        .darkerBlue
                                        .withOpacity(0.1)
                                    : Colors.white,
                              ),
                              child: Row(
                                children: [
                                  // Bank icon/logo placeholder
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .lighterBlue,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Center(
                                      child: Text(
                                        bankAccount.bankName.substring(0, 1),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Bank details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          bankAccount.bankName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .darkerBlue,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          bankAccount.iban,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Colors.grey.shade600,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Selection indicator
                                  if (selectedIban.value == bankAccount.iban)
                                    Icon(
                                      Icons.check_circle,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .darkerBlue,
                                      size: 24,
                                    )
                                  else
                                    Icon(
                                      Icons.radio_button_unchecked,
                                      color: Colors.grey.shade400,
                                      size: 24,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList()
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade50,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey.shade600),
                        const SizedBox(width: 12),
                        Text(
                          'No bank accounts found',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
