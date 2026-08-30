import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_dashboard/models/invoice_list_query.dart';
import 'package:slickbill/feature_dashboard/models/invoice_model.dart';
import 'package:slickbill/feature_dashboard/utils/sent_invoices_class.dart';
import 'package:slickbill/feature_dashboard/utils/invoice_csv_exporter.dart';
import 'package:slickbill/feature_dashboard/widgets/invoice_list_filter_bar.dart';
import 'package:slickbill/feature_dashboard/widgets/statistics_card.dart';

import '../../feature_auth/getx_controllers/user_controller.dart';
import '../getx_controllers/digital_invoice_controller.dart';
import '../widgets/sent_invoice_sheet.dart';
import '../widgets/grouped_invoice_card.dart';

class SentBills extends HookWidget {
  SentInvoicesClass sentInvoicesClass = SentInvoicesClass();
  final UserController userController = Get.find();
  final DigitalInvoiceController invoiceController =
      Get.find<DigitalInvoiceController>();

  SentBills({super.key});

  @override
  Widget build(BuildContext context) {
    var isLoading = useState<bool>(false);
    var hasLoaded = useState<bool>(false);
    var invoices = useState<List<InvoiceModel>?>([]);
    var pending = useState<double?>(0.0);
    var receivedThisMonth = useState<double?>(0.0);
    final filter = useState(InvoiceListQuery(
      month: currentInvoiceMonth(),
      status: InvoiceStatusFilter.all,
    ));
    final fetchRef = useRef<Future<void> Function()>(() async {});

    Future getInvoices() async {
      isLoading.value = true;
      final current = filter.value;

      final results = await Future.wait([
        sentInvoicesClass.getPrivateSentInvoices(query: current),
        sentInvoicesClass.getOpenInvoicesSum(),
        sentInvoicesClass.getPaidInMonth(current.monthStart),
      ]);

      final rows = results[0] as List<InvoiceModel>?;
      if (rows != null) {
        invoices.value = rows;
      }
      pending.value = results[1] as double? ?? 0.0;
      receivedThisMonth.value = results[2] as double? ?? 0.0;
      isLoading.value = false;
      hasLoaded.value = true;
    }

    fetchRef.value = getInvoices;

    Future updateInvoiceObsolete(InvoiceModel invoice, isObsolete) async {
      await sentInvoicesClass.updateInvoiceObsolete(invoice.id, isObsolete);
      await getInvoices();
      Navigator.of(context).pop();
    }

    Future<void> openInvoice(InvoiceModel invoice) async {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: Colors.transparent,
        builder: (context) => FractionallySizedBox(
          heightFactor: 0.94,
          child: SentInvoiceSheet(
            invoice: invoice,
            updateInvoiceObsolete: updateInvoiceObsolete,
          ),
        ),
      );
    }

    Future refreshAllData() async {
      await getInvoices();
    }

    useEffect(() {
      refreshAllData();
      return null;
    }, [filter.value.month.year, filter.value.month.month, filter.value.status, filter.value.allTime]);

    useEffect(() {
      final refreshWorker =
          ever<int>(invoiceController.sentListRefreshRequest, (_) {
        fetchRef.value();
      });

      return () {
        refreshWorker.dispose();
      };
    }, [userController.user.value.accessToken]);

    String groupKey(InvoiceModel i) {
      if (i.privateGroupId != null) {
        return 'group_${i.privateGroupId}';
      }
      return 'single_${i.invoiceNo}';
    }

    final monthName = DateFormat.MMMM().format(filter.value.monthStart);
    final rows = invoices.value ?? <InvoiceModel>[];

    return Column(
      children: [
        InvoiceListFilterBar(
          query: filter.value,
          onChanged: (next) => filter.value = next,
          exportEnabled: rows.isNotEmpty,
          onExport: () {
            InvoiceCsvExporter.exportSent(
              invoices: rows,
              query: filter.value,
            );
          },
        ),
        if (isLoading.value && hasLoaded.value)
          LinearProgressIndicator(
            minHeight: 2,
            color: Theme.of(context).colorScheme.blue,
            backgroundColor:
                Theme.of(context).colorScheme.blue.withOpacity(0.15),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: refreshAllData,
            color: Theme.of(context).colorScheme.light,
            backgroundColor: Theme.of(context).colorScheme.blue,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0.0, 12.0, 20.0, 20.0),
                child: !hasLoaded.value && isLoading.value
                    ? const Padding(
                        padding: EdgeInsets.only(top: 48),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : Column(
                        children: [
                          StatisticsCard(
                            pendingAmount: pending.value,
                            paidAmount: receivedThisMonth.value,
                            pendingLabel: 'lbl_WaitingForPayment'.tr,
                            paidLabel: 'lbl_ReceivedInMonth'.trParams({
                              'month': monthName,
                            }),
                          ),
                          const SizedBox(height: 12),
                          if (rows.isEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 24, 0, 0),
                              child: Text(
                                filter.value.emptyListNeedsMonth
                                    ? filter.value.emptyListLabelKey.trParams({
                                        'month': monthName,
                                      })
                                    : filter.value.emptyListLabelKey.tr,
                              ),
                            )
                          else
                            Builder(
                              builder: (context) {
                                final grouped = <String, List<InvoiceModel>>{};
                                for (final i in rows) {
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
                                          padding: const EdgeInsets.only(
                                              top: 20.0),
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
            ),
          ),
        ),
      ],
    );
  }
}
