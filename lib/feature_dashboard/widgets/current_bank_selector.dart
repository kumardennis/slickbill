import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/getx_controllers/current_bank_controller.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_auth/models/user_model.dart';
import 'package:slickbill/feature_auth/utils/supabase_auth_manger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CurrentBankSelector extends HookWidget {
  const CurrentBankSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final userController = Get.find<UserController>();
    final currentBankController = Get.find<CurrentBankController>();
    final authManager = SupabaseAuthManger();
    final client = Supabase.instance.client;

    // initial selection from currentBankController or from primary iban in list
    final ibans = userController.user.value.ibans ?? [];
    final primaryFromList = ibans.firstWhereOrNull((b) => b.isPrimary) ??
        (ibans.isNotEmpty ? ibans.first : null);

    final initialIban =
        currentBankController.current.value.iban ?? primaryFromList?.iban;

    final selectedIban = useState<String?>(initialIban);

    Future<void> _setPrimaryBank(BankAccount bankAccount) async {
      final user = userController.user.value;
      if (user.privateUserId == null) {
        Get.snackbar('Error', 'No private user profile found.');
        return;
      }
      final privateUserId = user.privateUserId!;

      try {
        // 1) Get latest ibans JSON from DB
        final existing = await client
            .from('private_users')
            .select('ibans')
            .eq('id', privateUserId)
            .maybeSingle();

        final List<dynamic> existingIbansJson =
            (existing?['ibans'] as List<dynamic>?) ?? [];

        // 2) Update primary flag in JSON
        for (final item in existingIbansJson) {
          if (item is Map<String, dynamic>) {
            item['isPrimary'] = (item['iban'] == bankAccount.iban);
          }
        }

        // 3) Also sync scalar columns to selected primary
        await client.from('private_users').update({
          'iban': bankAccount.iban,
          'bankAccountName': bankAccount.bankAccountName,
          'ibans': existingIbansJson,
        }).eq('id', privateUserId);

        // 4) Reload user so UserController has fresh ibans + primary values
        final session = client.auth.currentSession;
        if (session != null && session.user != null) {
          await authManager.loadFreshUser(
            session.user!.id,
            session.accessToken,
          );
        }

        // 5) Update current bank controller in memory
        currentBankController.loadCurrentBank(bankAccount);

        Get.snackbar(
          'Success',
          'Primary bank account updated.',
          snackPosition: SnackPosition.TOP,
        );
      } catch (e) {
        Get.snackbar(
          'Error',
          'Failed to update primary bank: $e',
          snackPosition: SnackPosition.TOP,
        );
      }
    }

    return Center(
      child: Column(
        children: [
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
                if (ibans.isNotEmpty)
                  ...ibans.map(
                    (bankAccount) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () async {
                          selectedIban.value = bankAccount.iban;
                          await _setPrimaryBank(bankAccount);
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
                              // Bank icon
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color:
                                      Theme.of(context).colorScheme.lighterBlue,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Center(
                                  child: Text(
                                    bankAccount.bankName.isNotEmpty
                                        ? bankAccount.bankName.substring(0, 1)
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bankAccount.bankAccountName ?? '-',
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
                                    const SizedBox(height: 2),
                                    Text(
                                      bankAccount.bankName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.grey.shade600,
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
                              Icon(
                                selectedIban.value == bankAccount.iban
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: selectedIban.value == bankAccount.iban
                                    ? Theme.of(context).colorScheme.darkerBlue
                                    : Colors.grey.shade400,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
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
