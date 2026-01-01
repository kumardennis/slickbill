import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_dashboard/models/invoice_model.dart';
import 'package:slickbill/feature_dashboard/utils/payment_class.dart';
import 'package:slickbill/feature_dashboard/utils/received_invoices_class.dart';
import 'package:slickbill/feature_dashboard/utils/show_verification_dialog.dart';
import 'package:slickbill/feature_dashboard/utils/striga_class.dart';
import 'package:slickbill/feature_dashboard/widgets/received_invoice_sheet.dart';
import 'package:slickbill/shared_widgets/custom_appbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReceivedInvoice extends HookWidget {
  final InvoiceModel invoice;
  ReceivedInvoicesClass receivedInvoicesClass = ReceivedInvoicesClass();
  PaymentClass payment = PaymentClass();
  StrigaClass striga = StrigaClass();
  final UserController userController = Get.find();

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

    Future createStrigaTransaction(InvoiceModel invoice, bool isPaid) async {
      context.loaderOverlay.show(
          widgetBuilder: (_) => Center(
                  child: Text(
                'inf_WontBeMoment'.tr,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.light),
              )));

      final challengeId = invoice.senderId != null
          ? await striga.initiateStrigaSepaTransaction(
              invoice.senderIban!, invoice.description, invoice.amount)
          : await striga.initiateStrigaTransaction(
              invoice.senders!.privateUsers!.userId,
              invoice.description,
              invoice.amount,
            );

      context.loaderOverlay.hide();

      if (challengeId.isEmpty) {
        return;
      }

      strigaChallengeId.value = challengeId;

      final verificationCode =
          await showVerificationDialog(context, challengeId);

      if (verificationCode != null && verificationCode.isNotEmpty) {
        context.loaderOverlay.show(
            widgetBuilder: (_) => Center(
                    child: Text(
                  'inf_WontBeMoment'.tr,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: Theme.of(context).colorScheme.light),
                )));

        final confirmSuccess = await striga.confirmStrigaTransaction(
            challengeId, verificationCode);

        if (confirmSuccess) {
          await updateInvoiceStatus(invoice, isPaid);
          Get.snackbar('Success', 'inf_PaymentConfirmed'.tr);
        } else {
          Get.snackbar('Error', 'Transaction confirmation failed');
        }

        context.loaderOverlay.hide();
      }
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
          createStrigaPayment: createStrigaTransaction,
          updateInvoiceObsolete: updateInvoiceObsolete),
    );
  }
}
