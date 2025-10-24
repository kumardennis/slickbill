import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_dashboard/models/invoice_model.dart';
import 'package:slickbill/feature_dashboard/utils/received_invoices_class.dart';
import 'package:slickbill/feature_dashboard/utils/sent_invoices_class.dart';
import 'package:slickbill/feature_dashboard/widgets/invoice_card.dart';
import 'package:slickbill/feature_dashboard/widgets/statistics_card.dart';

import '../../feature_auth/getx_controllers/user_controller.dart';
import '../../feature_auth/utils/money_formatter.dart';
import '../widgets/received_invoice_sheet.dart';
import '../widgets/sent_invoice_sheet.dart';

class SentBills extends HookWidget {
  SentInvoicesClass sentInvoicesClass = SentInvoicesClass();
  final UserController userController = Get.find();

  SentBills({super.key});

  @override
  Widget build(BuildContext context) {
    var isLoading = useState<bool>(false);
    var invoices = useState<List<InvoiceModel>?>([]);
    var pending = useState<double?>(0.0);
    var receivedThisMonth = useState<double?>(0.0);

    FormatNumber formatNumber = FormatNumber();

    Future getInvoices() async {
      isLoading.value = true;

      var response = await sentInvoicesClass.getPrivateSentInvoices();

      invoices.value = response;

      isLoading.value = false;
    }

    Future getPendingSum() async {
      var response = await sentInvoicesClass.getPendingInvoicesSum();

      pending.value = response;
    }

    Future getRceivedSum() async {
      var response = await sentInvoicesClass
          .getReceivedPaymentsThisMonth(userController.user.value.accessToken);

      receivedThisMonth.value = response;
    }

    Future updateInvoiceObsolete(InvoiceModel invoice, isObsolete) async {
      await sentInvoicesClass.updateInvoiceObsolete(invoice.id, isObsolete);
      await getInvoices();
      await getPendingSum();
      await getRceivedSum();
      Navigator.of(context).pop();
    }

    Future<void> openInvoice(InvoiceModel invoice) async {
      await showModalBottomSheet(
          context: context,
          builder: (context) => SentInvoiceSheet(
              invoice: invoice, updateInvoiceObsolete: updateInvoiceObsolete));
    }

    useEffect(() {
      getInvoices();
    }, [userController.user.value.accessToken]);

    useEffect(() {
      Future getPendingSum() async {
        var response = await sentInvoicesClass.getPendingInvoicesSum();

        pending.value = response;
      }

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
                      StatisticsCard(
                        pendingAmount: pending.value,
                        paidAmount: receivedThisMonth.value,
                        pendingLabel: 'lbl_Pending'.tr,
                        paidLabel: 'lbl_ReceivedThisMonth'.tr,
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      Column(
                        children: invoices.value!
                            .map((invoice) => GestureDetector(
                                  onTap: () async {
                                    await openInvoice(invoice);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 20.0),
                                    child: InvoiceCard(
                                        amount: invoice.amount,
                                        invoiceNo: invoice.invoiceNo,
                                        date: invoice.createdAt,
                                        dueDate: invoice.deadline,
                                        paidOnDate: invoice.paidOnDate,
                                        description: invoice.description,
                                        senderOrReeceiverName: invoice
                                                    .receivers.businessUsers !=
                                                null
                                            ? '${invoice.receivers.businessUsers?.publicName}'
                                            : '${invoice.receivers.privateUsers?.firstName} ${invoice.receivers.privateUsers?.lastName}',
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
