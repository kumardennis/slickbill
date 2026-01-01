import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_dashboard/utils/received_invoices_class.dart';
import 'package:slickbill/feature_dashboard/utils/sent_invoices_class.dart';
import 'package:slickbill/feature_dashboard/utils/striga_class.dart';

class WalletBalance extends HookWidget {
  const WalletBalance({super.key});

  @override
  Widget build(BuildContext context) {
    StrigaClass strigaClass = StrigaClass();
    SentInvoicesClass sentInvoicesClass = SentInvoicesClass();
    ReceivedInvoicesClass receivedInvoicesClass = ReceivedInvoicesClass();

    var balance = useState(0.0);
    var isLoading = useState(false);
    var pendingReceived = useState<double?>(0.0);
    var pendingSending = useState<double?>(0.0);
    final isMounted = useIsMounted();

    Future<void> fetchBalance() async {
      if (!isMounted()) return;
      isLoading.value = true;

      try {
        Map wallet = await strigaClass.getWallet();
        if (isMounted()) {
          balance.value =
              double.tryParse(wallet['hAmount']?.toString() ?? '0') ?? 0.0;
          isLoading.value = false;
        }
      } catch (e) {
        print('Error fetching balance: $e');
        if (isMounted()) {
          isLoading.value = false;
        }
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
      fetchBalance();
      getPendingSendingSum();
      getPendingReceivedSum();
      return null;
    }, []);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.darkerBlue,
            Theme.of(context).colorScheme.lighterBlue,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.darkerBlue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Balance',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 4),
                  isLoading.value
                      ? const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : Text(
                          '€ ${formatAmount(balance.value)}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 36,
                              ),
                        ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Balance Details Row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
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
                          Text(
                            'lbl_WaitingForPayment'.tr,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 12,
                                    ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '€ ${formatAmount(pendingSending.value)}',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
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
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
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
                          Text(
                            'lbl_PendingToPay'.tr,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 12,
                                    ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '€ ${formatAmount(pendingReceived.value)}',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
