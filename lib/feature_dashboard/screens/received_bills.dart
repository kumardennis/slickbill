import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_dashboard/getx_controllers/digital_invoice_controller.dart';
import 'package:slickbill/feature_dashboard/models/invoice_model.dart';
import 'package:slickbill/feature_dashboard/utils/payment_class.dart';
import 'package:slickbill/feature_dashboard/utils/received_invoices_class.dart';
import 'package:slickbill/feature_dashboard/utils/show_verification_dialog.dart';
import 'package:slickbill/feature_dashboard/widgets/invoice_card.dart';
import 'package:slickbill/feature_dashboard/widgets/received_invoice_sheet.dart';
import 'package:slickbill/feature_dashboard/widgets/statistics_card.dart';
import 'package:slickbill/services/biometric_auth_service.dart';
import 'package:slickbill/services/coinbase/coinbase_service.dart';
import 'package:slickbill/shared_widgets/cdp_webview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../feature_auth/getx_controllers/user_controller.dart';

class ReceivedBills extends HookWidget {
  const ReceivedBills({super.key});

  @override
  Widget build(BuildContext context) {
    final receivedInvoicesClass = ReceivedInvoicesClass();
    final payment = PaymentClass();
    final biometricAuth = BiometricAuthService();
    final UserController userController = Get.find();
    final DigitalInvoiceController invoiceController =
        Get.find<DigitalInvoiceController>();

    final supabase = Supabase.instance.client;

    final isLoading = useState<bool>(false);
    final invoices = useState<List<InvoiceModel>?>([]);
    final pending = useState<double?>(0.0);
    final paidThisMonth = useState<double?>(0.0);
    final callInProgress = useState<bool>(false);
    final strigaChallengeId = useState<String>("");

    Future<void> getInvoices() async {
      if (!context.mounted) return;
      isLoading.value = true;

      final response = await receivedInvoicesClass.getPrivateReceivedInvoices();
      if (!context.mounted) return;

      invoices.value = response;

      isLoading.value = false;
    }

    Future<void> getPendingSum() async {
      final response = await receivedInvoicesClass.getPendingInvoicesSum();
      if (!context.mounted) return;
      pending.value = response;
    }

    Future<void> getReceivedSum() async {
      final response = await receivedInvoicesClass
          .getPaidPaymentsThisMonth(userController.user.value.accessToken);
      if (!context.mounted) return;
      paidThisMonth.value = response;
    }

    Future<void> updateInvoiceStatus(InvoiceModel invoice, bool isPaid) async {
      await receivedInvoicesClass.updateInvoiceStatus(invoice.id, isPaid);
      await getInvoices();
      await getPendingSum();
      await getReceivedSum();
      if (!context.mounted) return;
      callInProgress.value = false;
      Navigator.of(context).pop();
    }

    Future<void> payInvoice(InvoiceModel invoice, bool isPaid) async {
      final token = await payment.getPaymentToken("LHV");

      if (token.isEmpty) {
        return;
      }

      final paymentSuccess = await payment.createSepaTransfer(
          "LHV", token, invoice.amount.toString());

      if (!paymentSuccess) {
        return;
      }

      await updateInvoiceStatus(invoice, isPaid);
    }

    Future<void> createCoinbaseTransaction(
        InvoiceModel invoice, bool isPaid) async {
      final authenticated = await biometricAuth.authenticateWithBiometrics(
        reason:
            'Authenticate to confirm payment of €${invoice.amount.toStringAsFixed(2)}',
      );

      if (!authenticated) {
        Get.snackbar(
          'Authentication Failed',
          'Biometric authentication is required to make payments.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      print('Creating Coinbase transaction...');
      print(invoice.senders?.privateUsers?.users);
      if (invoice.senders == null ||
          invoice.senders!.privateUsers!.users == null ||
          invoice.senders!.privateUsers!.users!.username.isEmpty) {
        Get.snackbar(
          'Error',
          'Sender Coinbase account information is missing.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
        );
        return;
      }
      final payment = await CoinbaseService.transferEURC(
        fromAccountName: userController.user.value.username,
        toAccountName: invoice.senders!.privateUsers!.users!.username ?? "",
        amount: invoice.amount,
      );

      if (!payment.containsKey('userOpHash')) {
        Get.snackbar(
          'Error',
          'Coinbase transaction failed.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
        );

        return;
      }

      await updateInvoiceStatus(invoice, isPaid);
    }

    Future<void> createCDPEmbeddedTransaction(InvoiceModel invoice) async {
      final walletAddress = userController.user.value.cdpWalletId;
      if (walletAddress == null || walletAddress.isEmpty) {
        Get.snackbar(
          'Wallet not connected',
          'Please connect your wallet before paying.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      // Open embedded wallet pay page; auto-close when txHash is available
      const baseUrl = 'https://slickbills-wallet-client.vercel.app';
      final result = await Get.to(() => CdpWebView(
            url:
                '$baseUrl/wallet/pay?to=${invoice.senders!.privateUsers!.users!.cdpWalletId}&amount=${invoice.amount}&description=${Uri.encodeComponent(invoice.description)}&receiver=${invoice.senders!.privateUsers!.firstName}',
            title: 'Send Payment',
            accessToken: userController.user.value.accessToken,
            autoCloseMode: CdpAutoCloseMode.pay,
          ));

      if (result == null) {
        Get.snackbar(
          'Payment Cancelled',
          'You cancelled the payment.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );

        return;
      }

      // If the WebView returns a txHash, consider it success and update invoice status
      final txHash = result['txHash'];
      if (txHash == null ||
          txHash == 'null' ||
          (txHash is String && txHash.isEmpty)) {
        Get.snackbar(
          'Error',
          'Payment was not completed.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      Get.snackbar(
        'Success',
        'Transaction: $txHash',
        backgroundColor: Theme.of(context).colorScheme.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );

      await invoiceController.updateTxHashForInvoice(invoice.id, txHash);

      await updateInvoiceStatus(invoice, true);
    }

    Future<void> updateInvoiceObsolete(
        InvoiceModel invoice, bool isObsolete) async {
      await receivedInvoicesClass.updateInvoiceObsolete(invoice.id, isObsolete);
      await getInvoices();
      await getPendingSum();
      await getReceivedSum();
      if (!context.mounted) return;
      Navigator.of(context).pop();
    }

    Future<void> openInvoice(InvoiceModel invoice) async {
      await showModalBottomSheet(
          context: context,
          builder: (context) => ReceivedInvoiceSheet(
              invoice: invoice,
              payInvoice: payInvoice,
              updateInvoiceStatus: updateInvoiceStatus,
              createCoinbaseTransaction: createCoinbaseTransaction,
              createCDPEmbeddedTransaction: createCDPEmbeddedTransaction,
              updateInvoiceObsolete: updateInvoiceObsolete));
    }

    useEffect(() {
      Future.microtask(() async {
        await getInvoices();
        await getPendingSum();
        await getReceivedSum();
      });

      final changes = supabase
          .channel('invoice-updates-received-bills')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'digital_invoices',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'receiverPrivateUserId',
              value: userController.user.value.privateUserId.toString(),
            ),
            callback: (payload) => getInvoices(),
          )
          .subscribe();

      return () async {
        try {
          await supabase.removeChannel(changes);
        } catch (_) {}
      };
    }, [userController.user.value.privateUserId]);

    return RefreshIndicator(
        color: Theme.of(context).colorScheme.light,
        backgroundColor: Theme.of(context).colorScheme.blue,
        onRefresh: () async {
          await getInvoices();
          await getPendingSum();
          await getReceivedSum();
        },
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0.0, 20.0, 20.0, 20.0),
            child: isLoading.value
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : invoices.value == null
                    ? Text('lbl_NoInvoices'.tr)
                    : Column(
                        children: [
                          StatisticsCard(
                            pendingAmount: pending.value,
                            paidAmount: paidThisMonth.value,
                            pendingLabel: 'lbl_Pending'.tr,
                            paidLabel: 'lbl_PaidThisMonth'.tr,
                          ),
                          const SizedBox(
                            height: 20,
                          ),
                          Column(
                            children: invoices.value!
                                .map((invoice) => Padding(
                                      padding: const EdgeInsets.only(top: 20.0),
                                      child: GestureDetector(
                                        onTap: () async {
                                          await openInvoice(invoice);
                                        },
                                        child: InvoiceCard(
                                            amount: invoice.amount,
                                            invoiceNo: invoice.invoiceNo,
                                            date: invoice.createdAt,
                                            dueDate: invoice.deadline,
                                            paidOnDate: invoice.paidOnDate,
                                            description: invoice.description,
                                            senderOrReeceiverName:
                                                '${invoice.senders?.privateUsers?.firstName} ${invoice.senders?.privateUsers?.lastName ?? ''}',
                                            status: invoice.status,
                                            isSeen: invoice.isSeen),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
          ),
        ));
  }
}
