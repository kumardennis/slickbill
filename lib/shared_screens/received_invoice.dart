import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_dashboard/getx_controllers/digital_invoice_controller.dart';
import 'package:slickbill/feature_dashboard/models/invoice_model.dart';
import 'package:slickbill/feature_dashboard/utils/payment_class.dart';
import 'package:slickbill/feature_dashboard/utils/received_invoices_class.dart';
import 'package:slickbill/feature_dashboard/utils/show_verification_dialog.dart';
import 'package:slickbill/feature_dashboard/widgets/received_invoice_sheet.dart';
import 'package:slickbill/services/biometric_auth_service.dart';
import 'package:slickbill/services/coinbase/coinbase_service.dart';
import 'package:slickbill/shared_widgets/cdp_webview.dart';
import 'package:slickbill/shared_widgets/custom_appbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReceivedInvoice extends HookWidget {
  final InvoiceModel invoice;
  ReceivedInvoicesClass receivedInvoicesClass = ReceivedInvoicesClass();
  PaymentClass payment = PaymentClass();
  final biometricAuth = BiometricAuthService();
  final UserController userController = Get.find();
  final DigitalInvoiceController invoiceController =
      Get.find<DigitalInvoiceController>();

  final supabase = Supabase.instance.client;

  ReceivedInvoice({super.key, required this.invoice});

  @override
  Widget build(BuildContext context) {
    var strigaChallengeId = useState("");

    Future updateInvoiceStatus(InvoiceModel invoice, isPaid) async {
      await receivedInvoicesClass.updateInvoiceStatus(invoice.id, isPaid);
      Navigator.of(context).pop();
    }

    Future payInvoice(InvoiceModel invoice, bool isPaid) async {
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
      if (invoice.senders == null ||
          invoice.senders!.privateUsers == null ||
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

      final payment = await CoinbaseService.transferEURC(
        fromAccountName: userController.user.value.username,
        toAccountName: invoice.senders!.privateUsers?.users!.username ?? "",
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

    Future updateInvoiceObsolete(InvoiceModel invoice, isObsolete) async {
      await receivedInvoicesClass.updateInvoiceObsolete(invoice.id, isObsolete);

      Navigator.of(context).pop();
    }

    return Scaffold(
      appBar: CustomAppbar(
        title: 'lbl_NewInvoiceReceived'.tr,
        appbarIcon: null,
      ),
      body: ReceivedInvoiceSheet(
          invoice: invoice,
          payInvoice: payInvoice,
          updateInvoiceStatus: updateInvoiceStatus,
          createCoinbaseTransaction: createCoinbaseTransaction,
          createCDPEmbeddedTransaction: createCDPEmbeddedTransaction,
          updateInvoiceObsolete: updateInvoiceObsolete),
    );
  }
}
