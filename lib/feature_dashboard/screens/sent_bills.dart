import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_dashboard/models/invoice_model.dart';
import 'package:slickbill/feature_dashboard/utils/received_invoices_class.dart';
import 'package:slickbill/feature_dashboard/utils/sent_invoices_class.dart';
import 'package:slickbill/feature_dashboard/widgets/invoice_card.dart';
import 'package:slickbill/feature_dashboard/widgets/statistics_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../feature_auth/getx_controllers/user_controller.dart';
import '../../feature_auth/utils/money_formatter.dart';
import '../widgets/received_invoice_sheet.dart';
import '../widgets/sent_invoice_sheet.dart';
import '../widgets/grouped_invoice_card.dart';

class SentBills extends HookWidget {
  SentInvoicesClass sentInvoicesClass = SentInvoicesClass();
  final UserController userController = Get.find();

  final supabase = Supabase.instance.client;

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

    Future refreshAllData() async {
      await getInvoices();
      await getPendingSum();
      await getRceivedSum();
    }

    useEffect(() {
      refreshAllData();

      final changes = supabase
          .channel('invoice-updates-received-bills')
          .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'digital_invoices',
              filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'senderPrivateUserId',
                  value: userController.user.value.privateUserId.toString()),
              callback: (payload) {
                if (Get.isSnackbarOpen) {
                  Get.closeCurrentSnackbar();
                }

                Get.snackbar(
                  'A SlickBill has been updated',
                  'Tap refresh to load latest data',
                  snackPosition: SnackPosition.TOP,
                  duration: const Duration(seconds: 5),
                  mainButton: TextButton(
                    onPressed: () async {
                      if (Get.isSnackbarOpen) {
                        Get.closeCurrentSnackbar();
                      }
                      await refreshAllData();
                    },
                    child: const Text('Refresh'),
                  ),
                );
              })
          .subscribe();

      return () => changes.unsubscribe();
    }, [userController.user.value.accessToken]);

    String groupKey(InvoiceModel i) {
      if (i.privateGroupId != null) {
        return 'group_${i.privateGroupId}';
      }
      return 'single_${i.invoiceNo}';
    }

    return RefreshIndicator(
        onRefresh: refreshAllData,
        color: Theme.of(context).colorScheme.light,
        backgroundColor: Theme.of(context).colorScheme.blue,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0.0, 20.0, 20.0, 20.0),
            child: isLoading.value
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : invoices.value == null || invoices.value!.isEmpty
                    ? Text('lbl_NoInvoices'.tr)
                    : Column(
                        children: [
                          StatisticsCard(
                            pendingAmount: pending.value,
                            paidAmount: receivedThisMonth.value,
                            pendingLabel: 'lbl_Pending'.tr,
                            paidLabel: 'lbl_ReceivedThisMonth'.tr,
                          ),
                          const SizedBox(height: 20),

                          // grouped render
                          Builder(
                            builder: (context) {
                              final grouped = <String, List<InvoiceModel>>{};
                              for (final i in invoices.value!) {
                                grouped
                                    .putIfAbsent(groupKey(i), () => [])
                                    .add(i);
                              }

                              final groups = grouped.values.toList()
                                ..sort((a, b) => b.first.createdAt
                                    .compareTo(a.first.createdAt));

                              return Column(
                                children: groups
                                    .map(
                                      (groupInvoices) => Padding(
                                        padding:
                                            const EdgeInsets.only(top: 20.0),
                                        child: GroupedInvoiceCard(
                                          invoices: groupInvoices,
                                          onTapInvoice: openInvoice,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              );
                            },
                          ),
                        ],
                      ),
          ),
        ));
  }
}
