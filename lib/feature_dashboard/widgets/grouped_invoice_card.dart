import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_dashboard/models/invoice_model.dart';
import 'package:slickbill/feature_dashboard/widgets/invoice_card.dart';

class GroupedInvoiceCard extends StatelessWidget {
  final List<InvoiceModel> invoices;
  final Future<void> Function(InvoiceModel invoice) onTapInvoice;

  const GroupedInvoiceCard({
    super.key,
    required this.invoices,
    required this.onTapInvoice,
  });

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) return const SizedBox.shrink();

    // If group size is 1 -> return single InvoiceCard
    if (invoices.length == 1) {
      final i = invoices.first;
      return GestureDetector(
        onTap: () => onTapInvoice(i),
        child: InvoiceCard(
          amount: i.amount,
          invoiceNo: i.invoiceNo,
          date: i.createdAt,
          dueDate: i.deadline,
          paidOnDate: i.paidOnDate,
          description: i.description,
          senderOrReeceiverName: i.receivers.businessUsers != null
              ? '${i.receivers.businessUsers?.publicName}'
              : '${i.receivers.privateUsers?.firstName} ${i.receivers.privateUsers?.lastName}',
          status: i.status,
          isSeen: i.isSeen,
        ),
      );
    }

    final first = invoices.first;
    final totalAmount = invoices.fold<double>(0.0, (sum, e) => sum + e.amount);
    final paidAmount = invoices
        .where((e) => e.status.toUpperCase() == 'PAID')
        .fold<double>(0.0, (sum, e) => sum + e.amount);

    String createdLabel = first.createdAt;
    try {
      createdLabel = DateFormat('EEE, dd MMM yyyy')
          .format(DateTime.parse(first.createdAt));
    } catch (_) {}

    final groupStatus = invoices.every((e) => e.status.toUpperCase() == 'PAID')
        ? 'Paid'
        : 'Unpaid';

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(0),
          topRight: Radius.circular(28),
          bottomLeft: Radius.circular(0),
          bottomRight: Radius.circular(28),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.turqouise,
            Theme.of(context).colorScheme.turqouise.withOpacity(0.7),
          ],
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          collapsedIconColor: Theme.of(context).colorScheme.yellow,
          iconColor: Theme.of(context).colorScheme.yellow,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '€ ${totalAmount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).colorScheme.yellow,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    'Total',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).colorScheme.lightGray,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                  ),
                ],
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '€ ${paidAmount.toStringAsFixed(2)}',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Theme.of(context).colorScheme.green,
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    Text(
                      'Received',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Theme.of(context).colorScheme.lightGray,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: groupStatus == 'Paid'
                      ? Theme.of(context).colorScheme.green.withOpacity(0.15)
                      : Theme.of(context).colorScheme.yellow.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  groupStatus,
                  style: TextStyle(
                    color: groupStatus == 'Paid'
                        ? Theme.of(context).colorScheme.green
                        : Theme.of(context).colorScheme.yellow,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  first.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.light,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$createdLabel • ${invoices.length} invoices',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.gray,
                      ),
                ),
              ],
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(0, 2, 0, 0),
          children: invoices
              .map(
                (i) => Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: GestureDetector(
                    onTap: () => onTapInvoice(i),
                    child: InvoiceCard(
                      amount: i.amount,
                      invoiceNo: i.invoiceNo,
                      date: i.createdAt,
                      dueDate: i.deadline,
                      paidOnDate: i.paidOnDate,
                      description: i.description,
                      senderOrReeceiverName: i.receivers.businessUsers != null
                          ? '${i.receivers.businessUsers?.publicName}'
                          : '${i.receivers.privateUsers?.firstName} ${i.receivers.privateUsers?.lastName}',
                      status: i.status,
                      isSeen: i.isSeen,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
