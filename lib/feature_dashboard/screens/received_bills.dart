import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_dashboard/models/invoice_model.dart';
import 'package:slickbill/feature_dashboard/utils/payment_class.dart';
import 'package:slickbill/feature_dashboard/utils/received_invoices_class.dart';
import 'package:slickbill/feature_dashboard/utils/show_verification_dialog.dart';
import 'package:slickbill/feature_dashboard/utils/striga_class.dart';
import 'package:slickbill/feature_dashboard/widgets/invoice_card.dart';
import 'package:slickbill/feature_dashboard/widgets/received_invoice_sheet.dart';
import 'package:slickbill/feature_dashboard/widgets/statistics_card.dart';

import '../../feature_auth/getx_controllers/user_controller.dart';
import '../../feature_auth/utils/money_formatter.dart';

class ReceivedBills extends HookWidget {
  ReceivedInvoicesClass receivedInvoicesClass = ReceivedInvoicesClass();
  PaymentClass payment = PaymentClass();
  StrigaClass striga = StrigaClass();
  final UserController userController = Get.find();
  bool callInProgress = false;
  var strigaChallengeId = useState("");

  ReceivedBills({super.key});

  @override
  Widget build(BuildContext context) {
    var isLoading = useState<bool>(false);
    var invoices = useState<List<InvoiceModel>?>([]);

    var pending = useState<double?>(0.0);
    var paidThisMonth = useState<double?>(0.0);

    FormatNumber formatNumber = FormatNumber();

    Future getInvoices() async {
      isLoading.value = true;

      var response = await receivedInvoicesClass.getPrivateReceivedInvoices();

      invoices.value = response;
      isLoading.value = false;
    }

    Future getPendingSum() async {
      var response = await receivedInvoicesClass.getPendingInvoicesSum();

      pending.value = response;
    }

    Future getRceivedSum() async {
      var response = await receivedInvoicesClass
          .getPaidPaymentsThisMonth(userController.user.value.accessToken);

      paidThisMonth.value = response;
    }

    Future updateInvoiceStatus(InvoiceModel invoice, isPaid) async {
      await receivedInvoicesClass.updateInvoiceStatus(invoice.id, isPaid);
      await getInvoices();
      await getPendingSum();
      await getRceivedSum();
      callInProgress = false;
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
      final challengeId = await striga.initiateStrigaTransaction(
        invoice.senders!.privateUsers!.userId,
        invoice.description,
        invoice.amount,
      );

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
                  'inf_CreatingTokenAndStartingPayment'.tr,
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
      await getInvoices();
      await getPendingSum();
      await getRceivedSum();
      Navigator.of(context).pop();
    }

    Future<void> openInvoice(InvoiceModel invoice) async {
      await showModalBottomSheet(
          context: context,
          builder: (context) => ReceivedInvoiceSheet(
              invoice: invoice,
              payInvoice: payInvoice,
              updateInvoiceStatus: updateInvoiceStatus,
              createStrigaPayment: createStrigaTransaction,
              updateInvoiceObsolete: updateInvoiceObsolete));
    }

    useEffect(() {
      getInvoices();
      getPendingSum();
      getRceivedSum();
    }, [userController.user.value.accessToken]);

    return (SingleChildScrollView(
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
                                            invoice.senderName,
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
