import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_dashboard/utils/received_invoices_class.dart';
import 'package:slickbill/feature_dashboard/utils/sent_invoices_class.dart';
import 'package:slickbill/services/coinbase/coinbase_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class WalletBalance extends HookWidget {
  const WalletBalance({super.key});

  @override
  Widget build(BuildContext context) {
    SentInvoicesClass sentInvoicesClass = SentInvoicesClass();
    ReceivedInvoicesClass receivedInvoicesClass = ReceivedInvoicesClass();
    UserController userController = Get.find();

    var pendingReceived = useState<double?>(0.0);
    var pendingSending = useState<double?>(0.0);

    // ✅ CDP Coinbase states
    var cdpAccount = useState<Map<String, dynamic>?>(null);
    var cdpBalances = useState<List<dynamic>>([]);
    var isLoadingCDP = useState(false);
    var eurcBalance = useState('0.00');

    final isMounted = useIsMounted();

    Future<void> fetchCDPBalances() async {
      if (!isMounted()) return;
      isLoadingCDP.value = true;

      try {
        final response = await CoinbaseService.getBalances(
          accountName: userController.user.value.username,
        );

        if (isMounted()) {
          cdpBalances.value = response['balances'] ?? [];

          // ✅ Extract EURC balance
          final eurcToken = cdpBalances.value.firstWhere(
            (balance) => balance['token']['symbol'] == 'EURC',
            orElse: () => null,
          );

          if (eurcToken != null) {
            final rawValue =
                double.tryParse(eurcToken['amount']['formatted']) ?? 0.00;
            eurcBalance.value = rawValue.toStringAsFixed(2);
          }

          isLoadingCDP.value = false;
        }
      } catch (e) {
        print('Error fetching CDP balances: $e');
        if (isMounted()) {
          isLoadingCDP.value = false;
        }
      }
    }

    Future<void> checkAndLoadCDPAccount() async {
      if (!isMounted()) return;
      isLoadingCDP.value = true;

      try {
        // ✅ This API call returns existing account or creates new one
        final account = await CoinbaseService.getAccount(
          accountName: userController.user.value.username,
        );

        if (isMounted() && account != null && account['smartAccount'] != null) {
          cdpAccount.value = account['smartAccount'];
          debugPrint(
              '✅ CDP Account loaded: ${account['smartAccount']['address']}');

          // Auto-fetch balances after loading account
          await fetchCDPBalances();
        }

        isLoadingCDP.value = false;
      } catch (e) {
        debugPrint('Error loading CDP account: $e');
        if (isMounted()) {
          isLoadingCDP.value = false;
        }
      }
    }

    Future<void> handleCreateCDPAccount() async {
      try {
        Get.dialog(
          const Center(child: CircularProgressIndicator()),
          barrierDismissible: false,
        );

        final account = await CoinbaseService.createOrGetAccount(
          accountName: userController.user.value.username,
        );

        Get.back();

        if (account != null && account['smartAccount'] != null) {
          cdpAccount.value = account['smartAccount'];

          Get.snackbar(
            'Success',
            'CDP Account created!\nAddress: ${account['smartAccount']['address']}',
            backgroundColor: Theme.of(context).colorScheme.green,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );

          // Auto-fetch balances
          await fetchCDPBalances();
        }
      } catch (e) {
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }

        debugPrint('Error creating CDP account: $e');

        Get.snackbar(
          'Error',
          'Failed to create CDP account: ${e.toString()}',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    }

    Future<void> handleRequestFaucet() async {
      try {
        Get.dialog(
          const Center(child: CircularProgressIndicator()),
          barrierDismissible: false,
        );

        final response = await CoinbaseService.requestTestnetFaucet(
          accountName: userController.user.value.username,
        );

        Get.back();

        if (response != null) {
          Get.snackbar(
            'Success',
            'Testnet EURC requested! Check your balance in a few seconds.',
            backgroundColor: Theme.of(context).colorScheme.green,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );

          // Wait 3 seconds then refresh balances
          await Future.delayed(const Duration(seconds: 3));
          await fetchCDPBalances();
        }
      } catch (e) {
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }

        Get.snackbar(
          'Error',
          'Failed to request faucet: ${e.toString()}',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    }

    Future<void> getPendingSendingSum() async {
      try {
        var response = await sentInvoicesClass.getPendingInvoicesSum();
        if (isMounted()) {
          pendingSending.value = response;
        }
      } catch (e) {
        print('Error fetching pending sending: $e');
      }
    }

    Future<void> getPendingReceivedSum() async {
      try {
        var response = await receivedInvoicesClass.getPendingInvoicesSum();
        if (isMounted()) {
          pendingReceived.value = response;
        }
      } catch (e) {
        print('Error fetching pending received: $e');
      }
    }

    String formatAmount(double? amount) {
      if (amount == null) return '0.00';
      return amount.toStringAsFixed(2);
    }

    useEffect(() {
      getPendingSendingSum();
      getPendingReceivedSum();
      checkAndLoadCDPAccount();
      return null;
    }, []);

    return Column(
      children: [
        // ✅ CDP Coinbase Balance Card
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.blue,
                Theme.of(context).colorScheme.turqouise,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.blue.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            color: Colors.white.withOpacity(0.8),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Coinbase CDP Wallet',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withOpacity(0.8),
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      isLoadingCDP.value
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              '€${eurcBalance.value}',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 36,
                                  ),
                            ),
                      const SizedBox(height: 4),
                      Text(
                        'EURC (Base Sepolia)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                      ),
                    ],
                  ),
                  // Coinbase logo
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.coins,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  // Create Account Button
                  if (cdpAccount.value == null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: handleCreateCDPAccount,
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text('Create Account'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Theme.of(context).colorScheme.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                  // Faucet & Refresh buttons (show after account created)
                  if (cdpAccount.value != null) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: handleRequestFaucet,
                        icon: const FaIcon(FontAwesomeIcons.faucet, size: 16),
                        label: const Text('Get Testnet'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Theme.of(context).colorScheme.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: fetchCDPBalances,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Icon(Icons.refresh, size: 20),
                    ),
                  ],
                ],
              ),

              // Show all balances (if available)
              if (cdpBalances.value.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All Balances',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      ...cdpBalances.value.map((balance) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                balance['token']['symbol'],
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                              ),
                              Text(
                                balance['amount']['formatted'],
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // ✅ Pending Transactions Cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .lightGreen
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .lightGreen
                          .withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.trending_up,
                            color: Theme.of(context).colorScheme.lightGreen,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'lbl_WaitingForPayment'.tr,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.dark,
                                    fontSize: 11,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '€${formatAmount(pendingSending.value)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context).colorScheme.dark,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.yellow.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          Theme.of(context).colorScheme.yellow.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.pending_actions,
                            color: Theme.of(context).colorScheme.yellow,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'lbl_PendingToPay'.tr,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.dark,
                                    fontSize: 11,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '€${formatAmount(pendingReceived.value)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context).colorScheme.dark,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
