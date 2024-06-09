import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_dashboard/models/invoice_model.dart';
import 'package:slickbill/feature_dashboard/utils/received_invoices_class.dart';
import 'package:slickbill/feature_dashboard/widgets/invoice_card.dart';
import 'package:slickbill/feature_dashboard/widgets/received_invoice_sheet.dart';

import '../../feature_auth/getx_controllers/user_controller.dart';
import '../../feature_auth/utils/money_formatter.dart';

class ReceivedBills extends HookWidget {
  ReceivedInvoicesClass receivedInvoicesClass = ReceivedInvoicesClass();
  final UserController userController = Get.find();

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

      var response = await receivedInvoicesClass
          .getPrivateReceivedInvoices(userController.user.value.accessToken);

      invoices.value = response;
      isLoading.value = false;
    }

    Future getPendingSum() async {
      var response = await receivedInvoicesClass
          .getPendingInvoicesSum(userController.user.value.accessToken);

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
      Navigator.of(context).pop();
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
              updateInvoiceStatus: updateInvoiceStatus,
              updateInvoiceObsolete: updateInvoiceObsolete));
    }

    useEffect(() {
      getInvoices();
    }, [userController.user.value.accessToken]);

    useEffect(() {
      getPendingSum();
    }, [userController.user.value.accessToken]);

    useEffect(() {
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
                      Container(
                        decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(50.0),
                                bottomRight: Radius.circular(10.0)),
                            gradient: LinearGradient(colors: [
                              Theme.of(context)
                                  .colorScheme
                                  .lightGray
                                  .withOpacity(0.1),
                              Theme.of(context).colorScheme.lightGray
                            ])),
                        height: 100,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: Center(
                                child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        pending.value != null
                                            ? formatNumber
                                                .formatMoney(pending.value!)
                                            : '-',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineLarge
                                            ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .yellow,
                                                fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        'lbl_Pending'.tr,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .yellow),
                                      )
                                    ]),
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        paidThisMonth.value != null
                                            ? formatNumber.formatMoney(
                                                paidThisMonth.value!)
                                            : '-',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineLarge
                                            ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .green,
                                                fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        'lbl_PaidThisMonth'.tr,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .green),
                                      )
                                    ]),
                              ),
                            )
                          ],
                        ),
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
