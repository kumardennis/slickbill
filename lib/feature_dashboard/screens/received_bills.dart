import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
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
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../feature_auth/getx_controllers/user_controller.dart';

class ReceivedBills extends HookWidget {
  const ReceivedBills({super.key});

  @override
  Widget build(BuildContext context) {
    final receivedInvoicesClass = ReceivedInvoicesClass();
    final payment = PaymentClass();
    final striga = StrigaClass();
    final UserController userController = Get.find();

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

    Future<void> createStrigaTransaction(
        InvoiceModel invoice, bool isPaid) async {
      context.loaderOverlay.show(
          widgetBuilder: (_) => Center(
                  child: Text(
                'inf_WontBeMoment'.tr,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.light),
              )));

      final challengeId = invoice.senderId == null
          ? await striga.initiateStrigaSepaTransaction(
              invoice.senderIban!, invoice.description, invoice.amount)
          : await striga.initiateStrigaTransaction(
              invoice.senders!.privateUsers!.userId,
              invoice.description,
              invoice.amount,
            );

      if (challengeId.isEmpty) {
        return;
      }

      context.loaderOverlay.hide();

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
              createStrigaPayment: createStrigaTransaction,
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
